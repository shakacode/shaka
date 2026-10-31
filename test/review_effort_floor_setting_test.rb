# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/repository_config'
require 'shaka/publication/settings'

# Path layouts differ by repository, so a repository chooses its own review-effort floors.
class ReviewEffortFloorSettingTest < Minitest::Test
  include EvidenceFixture

  EVIDENCE = [{ 'level' => 4, 'reason' => 'changes evidence checks', 'paths' => ['lib/evidence/**/*'] }].freeze

  def test_a_repository_list_replaces_the_shipped_floors
    with_repository('pr_description' => { 'human_review_floors' => EVIDENCE }) do |root|
      floors = Shaka::RepositoryConfig.load(root:).pr_description.fetch('human_review_floors')

      assert_equal 4, Shaka::ReviewEffortFloor.for(['lib/evidence/bind.rb'], floors)['level']
      assert_equal 1, Shaka::ReviewEffortFloor.for(['.github/workflows/ci.yml'], floors)['level']
    end
  end

  # Paths are compared in lowercase, so a word a maintainer capitalizes must still match.
  def test_floor_words_match_whatever_their_case
    floors = [{ 'level' => 4, 'reason' => 'changes deploys', 'words' => ['Deploy'] }]

    assert_equal 4, Shaka::ReviewEffortFloor.for(['script/deploy_app.sh'], floors)['level']
  end

  # A lexer's token.rb is ordinary code, so token is not a trust word by default.
  def test_the_shipped_floors_hold_token_at_two
    assert_equal 2, Shaka::ReviewEffortFloor.for(['lib/token.rb'])['level']
  end

  def test_malformed_floors_are_refused
    floor = { 'level' => 2, 'reason' => 'x', 'paths' => ['a'] }
    ['all', [floor.merge('level' => 6)], [floor.except('reason')], [floor.except('paths')],
     [floor.merge('paths' => [])], [floor.merge('glob' => ['b'])]].each do |floors|
      section = { 'human_review_floors' => floors }
      with_repository('pr_description' => section) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'pr_description.human_review_floors'
      end
    end
  end

  # The candidate branch cannot lower its own floor: description reads the trusted commit.
  def test_description_reads_floors_from_the_trusted_commit
    with_repository('pr_description' => { 'human_review_floors' => EVIDENCE }) do |root|
      system('git', '-C', root, 'init', '--quiet', exception: true)
      git(root, 'add', '-A')
      commit(root)
      ref = git(root, 'rev-parse', 'HEAD')
      lower_floors_in_candidate(root)

      _current, floors = Shaka::PublicationSettings.current_settings(root:, ref:, repository: 'shakacode/shaka')
      assert_equal EVIDENCE, floors
    end
  end

  private

  def lower_floors_in_candidate(root)
    path = File.join(root, '.agents/shaka/config.yml')
    config = YAML.safe_load_file(path)
    config['pr_description']['human_review_floors'] = [EVIDENCE.first.merge('level' => 1)]
    File.write(path, YAML.dump(config))
    git(root, 'add', '-A')
    commit(root)
  end
end
