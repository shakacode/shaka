# frozen_string_literal: true

require_relative 'merge_test'
require 'shaka/pull_changed_files'

# Answers the PR and file-list reads the risk gate makes beside the merge client's own.
class PullChangedFilesClient < MergeFixtures::Client
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

# The changed files the risk gate reads must belong to the exact head and an unmoved base.
class PullChangedFilesTest < Minitest::Test
  include MergeFixtures

  INSTRUCTIONS = 'skills/shaka/SKILL.md'

  # Reads the changed files on every gate pass, as MergeRiskGate does.
  class ReadingGate
    def verify!(github, head) = Shaka::PullChangedFiles.new.paths(github, head)
  end

  def setup
    super
    @client = PullChangedFilesClient.copy(@client)
    @client.files = %w[lib/fix.rb test/fix_test.rb]
    @client.pull_heads = [HEAD]
  end

  def paths = Shaka::PullChangedFiles.new.paths(@client, HEAD)

  def assert_refused(pattern)
    assert_match pattern, assert_raises(Shaka::Error) { paths }.message
  end

  def test_reads_the_changed_files_of_the_head
    assert_equal %w[lib/fix.rb test/fix_test.rb], paths
  end

  def test_a_renamed_file_counts_under_both_names
    def @client.api_list(_path) = [{ 'filename' => 'lib/moved.rb', 'previous_filename' => INSTRUCTIONS }]
    @client.files = ['lib/moved.rb']

    assert_equal ['lib/moved.rb', INSTRUCTIONS], paths
  end

  def test_an_incomplete_file_list_hands_back
    def @client.api(_path) = { 'head' => { 'sha' => HEAD }, 'changed_files' => 3 }

    assert_refused(/Cannot read the PR's changed files .*hand it to the user as Ask/)
  end

  def test_a_head_that_moves_while_the_list_is_read_needs_a_refresh
    @client.pull_heads = [HEAD, 'c' * 40]

    assert_refused(/\APR head changed; refresh/)
  end

  def test_a_base_rewritten_while_the_list_is_read_needs_a_refresh
    @client.pull_bases = ['d' * 40, 'e' * 40]

    assert_refused(/PR base moved while its changed files were read/)
  end

  def test_files_are_read_again_before_submission
    merge = Shaka::Merge.new(@client)
    merge.risk_gate = ReadingGate.new
    @client.pull_heads = [HEAD, HEAD, HEAD, 'c' * 40]
    error = assert_raises(Shaka::Error) { merge.call(head: HEAD, base: BASE, walkthrough: 17) }

    assert_match(/\APR head changed; refresh/, error.message)
    assert_empty @client.mutations
  end

  def test_without_a_gate_merge_reads_no_file_list
    def @client.api(_path) = raise('file list read')

    assert_equal 'MERGED', Shaka::Merge.new(@client).call(head: HEAD, base: BASE, walkthrough: 17).fetch('state')
  end
end
