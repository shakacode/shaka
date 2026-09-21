# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require 'yaml'

class SeamTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_help_succeeds
    output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--help')

    assert_predicate status, :success?, error
    assert_includes output, 'shaka seam check'
    assert_includes output, 'shaka seam init'
    assert_includes output, 'shaka seam pointer'
  end

  def test_help_before_the_operation_succeeds
    output, error, status = Open3.capture3(COMMAND, 'seam', '--help')

    assert_predicate status, :success?, error
    assert_includes output, 'shaka seam check'
    assert_includes output, 'shaka seam pointer'
  end

  def test_check_can_read_policy_from_a_trusted_git_ref
    with_repository do |root|
      commit_repository(root)
      path = File.join(root, '.agents/agent-workflow.yml')
      File.write(path, File.read(path).sub('preference: auto', 'preference: ask'))
      assert_equal 'auto', check_config(root, '--ref', 'HEAD').dig('merge', 'preference')
    end
  end

  def test_candidate_cannot_activate_optional_commands_missing_from_the_trusted_ref
    with_repository do |root|
      commit_repository(root)
      write_command(root, 'validate-local')
      write_command(root, 'trigger-hosted-ci')

      commands = check_config(root, '--ref', 'HEAD').fetch('commands')
      refute commands.key?('validate_local')
      refute commands.key?('trigger_hosted_ci')
    end
  end

  def test_trusted_optional_command_must_remain_available_in_the_candidate
    with_repository do |root|
      write_command(root, 'validate-local')
      commit_repository(root)
      FileUtils.rm(File.join(root, '.agents/bin/validate-local'))

      _output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--root', root, '--ref', 'HEAD')
      refute_predicate status, :success?
      assert_includes error, '.agents/bin/validate-local does not exist'
    end
  end

  def test_trusted_optional_commands_are_exposed_at_fixed_paths
    with_repository do |root|
      write_command(root, 'validate-local')
      write_command(root, 'trigger-hosted-ci')
      commit_repository(root)

      commands = check_config(root, '--ref', 'HEAD').fetch('commands')
      assert_equal '.agents/bin/validate-local', commands.fetch('validate_local')
      assert_equal '.agents/bin/trigger-hosted-ci', commands.fetch('trigger_hosted_ci')
    end
  end

  def test_a_trusted_hosted_ci_trigger_requires_trusted_local_validation
    with_repository do |root|
      write_command(root, 'trigger-hosted-ci')
      commit_repository(root)

      _output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--root', root, '--ref', 'HEAD')
      refute_predicate status, :success?
      assert_includes error, '.agents/bin/trigger-hosted-ci requires .agents/bin/validate-local'
    end
  end

  private

  def with_repository
    Dir.mktmpdir('shaka-seam') do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/bin'))
      write_commands(root)
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
      yield root
    end
  end

  def write_commands(root)
    %w[setup validate test].each { |name| write_command(root, name) }
  end

  def write_command(root, name)
    path = File.join(root, '.agents/bin', name)
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
  end

  def config
    {
      'version' => 1, 'base_branch' => 'main',
      'review' => { 'required' => 'meaningful_changes', 'check' => 'claude-review',
                    'reviewers' => [{ 'provider' => 'anthropic', 'model_family' => 'claude' }] },
      'merge' => { 'preference' => 'auto' }
    }
  end

  def check_config(root, *)
    output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--root', root, *)
    raise error unless status.success?

    JSON.parse(output)
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

class SeamPointerTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  # Break: a copy-ready AGENTS.md pointer that omits --ref would be pasted as
  # trusted policy loading, which is the Control Plane Flow failure mode.
  def test_pointer_renders_trust_safe_agents_guidance
    output, error, status = Open3.capture3(COMMAND, 'seam', 'pointer')

    assert_predicate status, :success?, error
    assert_empty error
    assert_trust_safe_pointer(output)
  end

  def test_pointer_refuses_check_and_init_options
    _output, error, status = Open3.capture3(COMMAND, 'seam', 'pointer', '--ref', 'HEAD')

    refute_predicate status, :success?
    assert_includes error, 'pointer'
  end

  private

  def assert_trust_safe_pointer(output)
    assert_includes output, '## Agent Workflow Configuration'
    assert_includes output, 'gh repo view'
    assert_includes output, 'immutable'
    assert_includes output, 'trusted installed'
    assert_includes output, '--ref'
    assert_includes output, 'fail-closed'
    assert_includes output, 'candidate'
    refute_includes output, 'Shaka V2'
  end
end
