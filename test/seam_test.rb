# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'seam_check_helpers'

class SeamTest < Minitest::Test
  include SeamCheckHelpers

  COMMAND = SeamCheckHelpers::COMMAND

  def test_help_succeeds
    output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--help')

    assert_predicate status, :success?, error
    assert_includes output, 'shaka seam check'
    assert_includes output, 'shaka seam init'
  end

  def test_help_before_the_operation_succeeds
    output, error, status = Open3.capture3(COMMAND, 'seam', '--help')

    assert_predicate status, :success?, error
    assert_includes output, 'shaka seam check'
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
end
