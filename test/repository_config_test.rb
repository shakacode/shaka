# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'yaml'
require 'shaka/repository_config'

module RepositoryConfigTestHelpers
  def with_outside_validate_symlink(root)
    Dir.mktmpdir('outside-command') do |outside_root|
      outside = File.join(outside_root, 'validate')
      File.write(outside, "#!/bin/sh\n")
      path = File.join(root, '.agents/bin/validate')
      FileUtils.rm(path)
      File.symlink(outside, path)
      yield
    end
  end

  def protection
    { 'required_checks' => ['validate'], 'direct_push' => false, 'force_push' => false,
      'branch_deletion' => false }
  end

  def merge_policy
    { 'preference' => 'auto', 'method' => 'squash', 'release' => 'explicit_approval' }
  end

  def with_repository(overrides = {})
    Dir.mktmpdir('shaka-repository-config') do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/bin'))
      create_commands(root)
      File.write(File.join(root, 'PLAN.md'), "# Plan\n")
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config.merge(overrides)))
      yield root
    end
  end

  def config
    {
      'version' => 1, 'base_branch' => 'main', 'plan' => 'PLAN.md', 'commands' => commands,
      'review' => { 'required' => 'meaningful_changes', 'check' => 'claude-review',
                    'model_family' => 'claude', 'provider' => 'anthropic', 'draft' => false },
      'merge' => merge_policy, 'protection' => protection, 'trusted_actions' => ['actions/checkout']
    }
  end

  def create_commands(root)
    %w[setup validate test].each { |name| create_command(root, name) }
  end

  def create_command(root, name)
    path = File.join(root, '.agents/bin', name)
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
  end

  def commands
    %w[setup validate test].to_h { |name| [name, ".agents/bin/#{name}"] }
  end

  def optional_commands
    { 'validate_full' => '.agents/bin/validate_full',
      'trigger_hosted_ci' => '.agents/bin/trigger_hosted_ci' }
  end
end

class RepositoryConfigTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_loads_the_repository_contract
    with_repository do |root|
      config = Shaka::RepositoryConfig.load(root:)

      assert_equal 'main', config.base_branch
      assert_equal '.agents/bin/validate', config.command('validate')
      assert_equal 'auto', config.merge.fetch('preference')
      assert_equal ['validate'], config.protection.fetch('required_checks')
    end
  end

  def test_loads_the_review_policy
    with_repository do |root|
      review = Shaka::RepositoryConfig.load(root:).review

      assert_equal ['meaningful_changes', 'claude', false],
                   review.values_at('required', 'model_family', 'draft')
    end
  end

  def test_rejects_unknown_keys
    with_repository('surprise' => true) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'unknown key: surprise'
    end
  end

  def test_rejects_duplicate_keys_before_yaml_discards_them
    with_repository do |root|
      path = File.join(root, '.agents/agent-workflow.yml')
      File.write(path, File.read(path).sub('base_branch: main', "base_branch: main\nbase_branch: trunk"))

      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'duplicate key: base_branch'
    end
  end

  def test_rejects_a_command_outside_the_repository
    with_repository('commands' => commands.merge('validate' => '../validate')) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'commands.validate must stay inside the repository'
    end
  end

  def test_rejects_a_missing_command
    with_repository do |root|
      FileUtils.rm(File.join(root, '.agents/bin/validate'))

      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'commands.validate does not exist'
    end
  end

  def test_rejects_a_command_symlink_outside_the_repository
    with_repository do |root|
      with_outside_validate_symlink(root) do
        message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message
        assert_includes message, 'commands.validate must resolve inside the repository'
      end
    end
  end

  def test_rejects_an_unsupported_merge_preference
    with_repository('merge' => merge_policy.merge('preference' => 'sometimes')) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message
      assert_includes message, 'merge.preference must be ask or auto'
    end
  end

  def test_loads_optional_full_validation_and_hosted_ci_commands
    with_repository('commands' => commands.merge(optional_commands)) do |root|
      optional_commands.each_key { |name| create_command(root, name) }
      config = Shaka::RepositoryConfig.load(root:)
      actual = optional_commands.keys.map { |name| config.command(name) }

      assert_equal optional_commands.values, actual
    end
  end

  def test_requires_reviewer_identity_and_draft_support
    review = { 'required' => 'meaningful_changes', 'check' => 'claude-review' }
    with_repository('review' => review) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message

      assert_includes message, 'missing review key: model_family'
    end
  end

  def test_rejects_a_merge_method_the_helper_cannot_honor
    with_repository('merge' => merge_policy.merge('method' => 'rebase')) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message
      assert_includes message, 'merge.method must be squash'
    end
  end

  def test_requires_at_least_one_native_check
    with_repository('protection' => protection.merge('required_checks' => [])) do |root|
      message = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }.message
      assert_includes message, 'protection.required_checks must not be empty'
    end
  end
end
