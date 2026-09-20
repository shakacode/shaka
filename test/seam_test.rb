# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require 'yaml'

class SeamTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_help_succeeds
    output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--help')

    assert status.success?, error
    assert_includes output, 'shaka seam check'
    assert_includes output, 'shaka seam init'
  end

  def test_help_before_the_operation_succeeds
    output, error, status = Open3.capture3(COMMAND, 'seam', '--help')

    assert status.success?, error
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
    %w[setup validate test].each do |name|
      path = File.join(root, '.agents/bin', name)
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
    end
  end

  def config
    {
      'version' => 1, 'base_branch' => 'main',
      'commands' => %w[setup validate test].to_h { |name| [name, ".agents/bin/#{name}"] },
      'review' => { 'required' => 'meaningful_changes', 'check' => 'claude-review',
                    'reviewers' => [{ 'provider' => 'anthropic', 'model_family' => 'claude' }] },
      'merge' => { 'preference' => 'auto', 'method' => 'squash', 'release' => 'explicit_approval' },
      'protection' => { 'required_checks' => ['validate'], 'direct_push' => false,
                        'force_push' => false, 'branch_deletion' => false }
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
