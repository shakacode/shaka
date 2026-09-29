# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require 'yaml'
require_relative 'reviewer_command_fixture'

# The command the workflow invokes, and the trusted-ref path that keeps a candidate branch from
# nominating its own reviewer.
class ReviewerCommandTest < Minitest::Test
  include ReviewerCommandFixture

  def test_selects_a_reviewer_from_the_seam
    with_repository do |root|
      result = reviewer(root, '--implementer', 'anthropic/claude')

      assert_equal 'different_provider', result.fetch('outcome')
      assert_equal 'openai/codex', result.fetch('reviewer')
    end
  end

  def test_skips_an_unavailable_reviewer
    with_repository do |root|
      result = reviewer(root, '--implementer', 'anthropic/claude',
                        '--unavailable', 'openai/codex')

      assert_equal 'xai/grok', result.fetch('reviewer')
    end
  end

  # A candidate that rewrites review.local_review_agents must not be able to nominate its own family.
  def test_reads_the_reviewer_list_from_the_trusted_ref
    with_repository do |root|
      commit_repository(root)
      rewrite_reviewers(root, [{ 'provider' => 'anthropic', 'model_family' => 'claude' }])

      candidate = reviewer(root, '--implementer', 'anthropic/claude')
      trusted = reviewer(root, '--ref', 'HEAD', '--implementer', 'anthropic/claude')

      assert_equal 'same_provider', candidate.fetch('outcome')
      assert_equal 'openai/codex', trusted.fetch('reviewer')
    end
  end

  def test_validates_optional_command_migration_in_the_candidate_checkout
    { 'validate-local' => '.agents/bin/validate-local does not exist',
      'validate_local' => '.agents/bin/validate_local requires the standard entry point' }.each do |name, expected|
      with_repository do |root|
        write_command(root, name)
        commit_repository(root)
        FileUtils.rm(File.join(root, '.agents/bin/validate-local')) if name == 'validate-local'
        assert_reviewer_rejects(root, expected)
      end
    end
  end

  def test_requires_at_least_one_implementer
    with_repository do |root|
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root)

      refute_predicate status, :success?
      assert_includes error, '--implementer is required'
    end
  end

  def test_rejects_an_identity_without_a_model_family
    with_repository do |root|
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root,
                                        '--implementer', 'anthropic')

      refute_predicate status, :success?
      assert_includes error, 'PROVIDER/MODEL_FAMILY'
    end
  end

  private

  def assert_reviewer_rejects(root, expected)
    _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, '--ref', 'HEAD',
                                      '--implementer', 'anthropic/claude')
    assert_includes error, expected, "expected reviewer failure, got status #{status.exitstatus}"
  end

  def commit_repository(root)
    git!(root, 'init')
    git!(root, 'add', '.')
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'trusted')
  end

  def git!(root, *)
    output, status = Open3.capture2e('git', '-C', root, *)
    raise output unless status.success?
  end
end
