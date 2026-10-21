# frozen_string_literal: true

require_relative 'merge_test'
require_relative 'repository_fixture'
require 'shaka/merge_review_floor'
require 'shaka/repository_config'

# Answers the PR and file-list reads the floor check makes beside the merge client's own.
class MergeReviewFloorClient < MergeFixtures::Client
  attr_accessor :files, :pull_heads, :pull_bases

  def self.copy(client)
    new.tap do |copy|
      %i[snapshots comments review_result mutation_result].each do |name|
        copy.public_send(:"#{name}=", client.public_send(name))
      end
      copy.checks = client.required_checks
    end
  end

  def repository = 'owner/repo'
  def number = 42

  def api(path)
    raise "unexpected read #{path}" unless path == 'repos/owner/repo/pulls/42'

    head = pull_heads.length > 1 ? pull_heads.shift : pull_heads.first
    bases = (@pull_bases ||= ['d' * 40])
    base = bases.length > 1 ? bases.shift : bases.first
    { 'head' => { 'sha' => head }, 'base' => { 'sha' => base }, 'changed_files' => files.length }
  end

  def api_list(path)
    raise "unexpected list #{path}" unless path.start_with?('repos/owner/repo/pulls/42/files')

    files.map { |name| { 'filename' => name } }
  end
end

# merge.auto_max_review_floor sends a PR back to the user when its changed paths set a higher floor.
class MergeReviewFloorTest < Minitest::Test
  include MergeFixtures

  INSTRUCTIONS = 'skills/shaka/SKILL.md'

  def setup
    super
    @client = MergeReviewFloorClient.copy(@client)
    @client.files = %w[lib/fix.rb test/fix_test.rb]
    @client.pull_heads = [HEAD]
    @merge = Shaka::Merge.new(@client)
  end

  def merge_with(max = 2, confirmed_head: nil, floors: nil)
    @merge.review_floor = Shaka::MergeReviewFloor.new(max, floors:, confirmed_head:)
    @merge.call(head: HEAD, base: BASE, walkthrough: 17)
  end

  def assert_held(pattern, max = 2, **)
    error = assert_raises(Shaka::Error) { merge_with(max, **) }
    assert_match pattern, error.message
    assert_empty @client.mutations
  end

  def test_code_and_tests_at_the_floor_merge
    assert_equal 'MERGED', merge_with.fetch('state')
  end

  def test_a_path_above_the_floor_hands_back_naming_the_file_and_reason
    @client.files += [INSTRUCTIONS]

    assert_held(/SKILL\.md sets review floor 3 \(changes agent instructions\), above .*Ask.*--limits-confirmed-head/)
  end

  def test_shaka_configuration_hands_back_even_when_the_floors_omit_it
    @client.files = ['.agents/shaka/config.yml']
    floors = [{ 'level' => 1, 'reason' => 'anything', 'paths' => ['**/*'] }]

    assert_held(%r{\.agents/shaka/config\.yml changes Shaka's configuration}, 4, floors:)
  end

  def test_repository_floors_replace_the_shipped_ones
    @client.files = ['docs/guide.md']
    floors = [{ 'level' => 5, 'reason' => 'changes docs for users', 'paths' => ['docs/**/*'] }]

    assert_held(%r{docs/guide\.md sets review floor 5 \(changes docs for users\)}, floors:)
  end

  def test_a_renamed_file_counts_under_its_old_name
    @client.files = ['lib/moved.rb']
    def @client.api_list(_path) = [{ 'filename' => 'lib/moved.rb', 'previous_filename' => INSTRUCTIONS }]

    assert_held(/SKILL\.md sets review floor 3/)
  end

  def test_confirmation_of_the_current_head_merges_above_the_floor
    @client.files += [INSTRUCTIONS]

    assert_equal 'MERGED', merge_with(confirmed_head: HEAD).fetch('state')
  end

  def test_an_incomplete_file_list_hands_back
    def @client.api(_path) = { 'head' => { 'sha' => HEAD }, 'changed_files' => 3 }

    assert_held(/Cannot read the PR's changed files .*hand it to the user as Ask/)
  end

  def test_a_head_that_moves_while_the_list_is_read_needs_a_refresh
    @client.pull_heads = [HEAD, 'c' * 40]

    assert_held(/\APR head changed; refresh/)
  end

  def test_a_base_rewritten_while_the_list_is_read_needs_a_refresh
    @client.pull_bases = ['d' * 40, 'e' * 40]

    assert_held(/PR base moved while its changed files were read/)
  end

  def test_files_are_read_again_before_submission
    @client.pull_heads = [HEAD, HEAD, HEAD, 'c' * 40]

    assert_held(/\APR head changed; refresh/)
  end

  def test_a_path_no_repository_floor_covers_sits_at_floor_one
    floors = [{ 'level' => 5, 'reason' => 'changes docs for users', 'paths' => ['docs/**/*'] }]

    assert_equal 'MERGED', merge_with(1, floors:).fetch('state')
  end

  def test_the_top_floor_reads_no_file_list
    def @client.api(_path) = raise('file list read')

    assert_equal 'MERGED', merge_with(5).fetch('state')
    assert_equal 'MERGED', Shaka::Merge.new(@client).call(head: HEAD, base: BASE, walkthrough: 17).fetch('state')
  end
end

class MergeReviewFloorSettingTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_defaults_to_the_top_floor
    with_repository do |root|
      assert_equal 5, Shaka::RepositoryConfig.load(root:).merge.fetch('auto_max_review_floor')
    end
  end

  def test_a_repository_can_lower_it
    with_repository('merge' => { 'preference' => 'auto', 'auto_max_review_floor' => 2 }) do |root|
      assert_equal 2, Shaka::RepositoryConfig.load(root:).merge.fetch('auto_max_review_floor')
    end
  end

  def test_rejects_values_outside_the_floor_levels
    [0, 6, '2', 2.5].each do |value|
      with_repository('merge' => { 'preference' => 'auto', 'auto_max_review_floor' => value }) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

        assert_includes error.message, 'merge.auto_max_review_floor must be a whole number from 1 to 5'
      end
    end
  end
end
