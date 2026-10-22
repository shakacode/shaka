# frozen_string_literal: true

# Proves description returns the trusted PR evidence guide with every publication, and nothing when unset.

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'

class CliDescriptionGuidanceTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'The guide comes back with the description.'
  GUIDE = '.agents/pr-evidence.md'

  def test_a_configured_guide_is_returned_with_the_publication
    with_repository('project_guidance' => { 'pr_evidence' => GUIDE }) do |root|
      write_guide(root, 'Show the rendering on the PR.')
      commit(root)
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, ref: true)

        assert_predicate status, :success?, error
        assert_equal "Show the rendering on the PR.\n", JSON.parse(output).fetch('pr_evidence_guide')
        assert_path_exists File.join(dir, 'published.md')
      end
    end
  end

  def test_the_guide_comes_from_the_trusted_commit_not_the_checkout
    with_repository('project_guidance' => { 'pr_evidence' => GUIDE }) do |root|
      write_guide(root, 'Trusted requirement.')
      commit(root)
      write_guide(root, 'Candidate rewrite.')
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, ref: true)

        assert_predicate status, :success?, error
        assert_equal "Trusted requirement.\n", JSON.parse(output).fetch('pr_evidence_guide')
      end
    end
  end

  def test_an_unreadable_guide_is_reported_without_refusing_publication
    with_repository('project_guidance' => { 'pr_evidence' => GUIDE }) do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, ref: true)

        assert_predicate status, :success?, error
        assert_includes JSON.parse(output).fetch('pr_evidence_guide'), 'could not be read'
        assert_path_exists File.join(dir, 'published.md')
      end
    end
  end

  def test_an_unset_guide_adds_nothing_to_the_result
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, ref: true)

        assert_predicate status, :success?, error
        refute_includes JSON.parse(output).keys, 'pr_evidence_guide'
        assert_path_exists File.join(dir, 'published.md')
      end
    end
  end

  private

  def write_guide(root, text)
    FileUtils.mkdir_p(File.dirname(File.join(root, GUIDE)))
    File.write(File.join(root, GUIDE), "#{text}\n")
  end
end
