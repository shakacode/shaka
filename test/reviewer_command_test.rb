# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require 'yaml'

# The command the workflow invokes, and the trusted-ref path that keeps a candidate branch from
# nominating its own reviewer.
class ReviewerCommandTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_selects_a_reviewer_from_the_seam
    with_repository do |root|
      result = reviewer(root, '--implementer', 'anthropic/claude')

      assert_equal 'alternate', result.fetch('outcome')
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

  # A candidate that rewrites review.reviewers must not be able to nominate its own family.
  def test_reads_the_reviewer_list_from_the_trusted_ref
    with_repository do |root|
      commit_repository(root)
      rewrite_reviewers(root, [{ 'provider' => 'anthropic', 'model_family' => 'claude' }])

      candidate = reviewer(root, '--implementer', 'anthropic/claude')
      trusted = reviewer(root, '--ref', 'HEAD', '--implementer', 'anthropic/claude')

      assert_equal 'outside_list', candidate.fetch('outcome')
      assert_equal 'openai/codex', trusted.fetch('reviewer')
    end
  end

  def test_requires_at_least_one_implementer
    with_repository do |root|
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root)

      refute status.success?
      assert_includes error, '--implementer is required'
    end
  end

  def test_rejects_an_identity_without_a_model_family
    with_repository do |root|
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root,
                                        '--implementer', 'anthropic')

      refute status.success?
      assert_includes error, 'PROVIDER/MODEL_FAMILY'
    end
  end

  private

  def reviewer(root, *)
    output, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, *)
    raise error unless status.success?

    JSON.parse(output)
  end

  def rewrite_reviewers(root, reviewers)
    path = File.join(root, '.agents/agent-workflow.yml')
    config = YAML.safe_load_file(path)
    config['review']['reviewers'] = reviewers
    File.write(path, YAML.dump(config))
  end

  def with_repository
    Dir.mktmpdir('shaka-reviewer') do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/bin'))
      %w[setup validate test].each do |name|
        path = File.join(root, '.agents/bin', name)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
      yield root
    end
  end

  def config
    { 'version' => 1, 'base_branch' => 'main',
      'commands' => %w[setup validate test].to_h { |n| [n, ".agents/bin/#{n}"] },
      'review' => { 'required' => 'meaningful_changes', 'check' => 'claude-review',
                    'reviewers' => [{ 'provider' => 'anthropic', 'model_family' => 'claude' },
                                    { 'provider' => 'openai', 'model_family' => 'codex' },
                                    { 'provider' => 'xai', 'model_family' => 'grok' }] },
      'merge' => { 'preference' => 'ask', 'method' => 'squash', 'release' => 'explicit_approval' },
      'protection' => { 'required_checks' => ['validate'], 'direct_push' => false,
                        'force_push' => false, 'branch_deletion' => false } }
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
