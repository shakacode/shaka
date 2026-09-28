# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'configuration_layout_fixture'
require 'shaka/configuration'

module PrivateSourceFixture
  include ConfigurationLayoutFixture

  def with_git_repository
    Dir.mktmpdir('shaka-private') do |root|
      system('git', '-C', root, 'init', '--quiet', exception: true)
      system('git', '-C', root, 'config', 'user.name', 'Test', exception: true)
      system('git', '-C', root, 'config', 'user.email', 'test@example.com', exception: true)
      yield root
    end
  end

  def with_private_repository
    with_git_repository do |root|
      ref = commit_project(root)
      write_private_seam(root)
      yield root, ref
    end
  end

  def commit_project(root)
    File.write(File.join(root, 'README.md'), "project\n")
    system('git', '-C', root, 'add', 'README.md', exception: true)
    system('git', '-C', root, 'commit', '--quiet', '-m', 'project', exception: true)
    head(root)
  end

  def head(root)
    Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip
  end

  def write_private_seam(root)
    FileUtils.mkdir_p(File.join(root, '.agents/shaka/bin'))
    create_new_commands(root)
    File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(config))
  end

  def report(root, ref)
    Shaka::Configuration.private_source(root:, ref:)
  end

  def add_optional(root, name)
    path = File.join(root, '.agents/shaka/bin', name)
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
  end
end

class PrivateSourceStateTest < Minitest::Test
  include PrivateSourceFixture

  def test_absent_private_source
    with_git_repository do |root|
      result = report(root, commit_project(root))
      assert_equal 'absent', result.status
      assert_equal 'absent', result.trusted_source
      assert_empty result.inventory
    end
  end

  def test_complete_inventory
    with_private_repository do |root, ref|
      result = report(root, ref)
      assert_equal 'complete', result.status
      assert_equal(expected_paths, result.inventory.map { |entry| entry[:path] }.sort)
      assert_equal 0o755, result.inventory.find { |entry| entry[:path].end_with?('/validate') }[:mode]
    end
  end

  def test_hidden_files_are_inventoried
    with_private_repository do |root, ref|
      File.write(File.join(root, '.agents/shaka/.hidden'), 'extra')
      paths = report(root, ref).inventory.map { |entry| entry[:path] }
      assert_includes paths, '.agents/shaka/.hidden'
    end
  end

  def test_complete_candidate_settings
    with_private_repository do |root, ref|
      assert_equal '.agents/shaka/bin/test', report(root, ref).candidate_config.command('test')
    end
  end

  def test_private_source_never_grants_trusted_authority
    with_private_repository do |root, ref|
      result = report(root, ref)
      assert_equal 'private/local', result.mode
      refute_predicate result, :grants_policy?
      refute_predicate result, :grants_merge_authority?
      refute result.to_h.fetch('grants_policy')
    end
  end

  def test_ref_must_be_an_immutable_commit
    with_private_repository do |root, _ref|
      error = assert_raises(Shaka::Error) { report(root, 'HEAD') }
      assert_includes error.message, 'immutable commit SHA'
    end
  end

  def test_missing_required_command_is_partial
    with_private_repository do |root, ref|
      File.delete(File.join(root, '.agents/shaka/bin/test'))
      result = report(root, ref)
      assert_equal 'partial', result.status
      assert_includes result.blockers.join(' '), '.agents/shaka/bin/test'
    end
  end

  def test_optional_commands_must_form_a_pair
    with_private_repository do |root, ref|
      add_optional(root, 'validate-local')
      assert_equal 'partial', report(root, ref).status
      add_optional(root, 'trigger-hosted-ci')
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_legacy_candidate_conflicts
    with_private_repository do |root, ref|
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
      assert_equal 'conflicting', report(root, ref).status
    end
  end

  private

  def expected_paths
    %w[.agents/shaka .agents/shaka/bin .agents/shaka/bin/setup .agents/shaka/bin/test
       .agents/shaka/bin/validate .agents/shaka/config.yml].sort
  end
end

class PrivateSourceSafetyTest < Minitest::Test
  include PrivateSourceFixture

  def test_tracked_private_file_conflicts
    with_private_repository do |root, ref|
      system('git', '-C', root, 'add', '.agents/shaka/config.yml', exception: true)
      result = report(root, ref)
      assert_equal 'conflicting', result.status
      assert_includes result.blockers.join(' '), 'tracked'
    end
  end

  def test_default_branch_policy_is_reported_separately
    with_private_repository do |root, _ref|
      system('git', '-C', root, 'add', '.agents/shaka/config.yml', exception: true)
      system('git', '-C', root, 'commit', '--quiet', '-m', 'team settings', exception: true)
      result = report(root, head(root))
      assert_equal 'conflicting', result.status
      assert_equal 'present', result.trusted_source
      refute_predicate result, :grants_policy?
    end
  end

  def test_preflight_does_not_change_files_or_index
    with_private_repository do |root, ref|
      path = File.join(root, '.agents/shaka/config.yml')
      before = [File.binread(path), File.binread(File.join(root, '.git/index'))]
      assert_equal 'complete', report(root, ref).status
      after = [File.binread(path), File.binread(File.join(root, '.git/index'))]
      assert_equal before, after
    end
  end

  def test_external_symlink_is_unsafe_and_inventoried
    with_private_repository do |root, ref|
      File.symlink('/etc/passwd', File.join(root, '.agents/shaka/escape'))
      result = report(root, ref)
      assert_equal 'unsafe_file', result.status
      assert_equal '/etc/passwd', result.inventory.find { |entry| entry[:type] == 'symlink' }[:target]
    end
  end

  def test_config_symlink_is_unsafe
    with_private_repository do |root, ref|
      path = File.join(root, '.agents/shaka/config.yml')
      File.rename(path, File.join(root, '.agents/shaka/copy.yml'))
      File.symlink('copy.yml', path)
      assert_equal 'unsafe_file', report(root, ref).status
    end
  end

  def test_safe_symlink_and_special_file
    with_private_repository do |root, ref|
      File.symlink('test', File.join(root, '.agents/shaka/bin/extra'))
      result = report(root, ref)
      assert_equal 'complete', result.status
      assert_equal 'test', result.inventory.find { |entry| entry[:type] == 'symlink' }[:target]
      system('mkfifo', File.join(root, '.agents/shaka/fifo'), exception: true)
      assert_equal 'unsafe_file', report(root, ref).status
    end
  end

  def test_untracked_prompt_outside_private_tree_is_partial
    with_private_repository do |root, ref|
      File.write(File.join(root, 'review.md'), 'private prompt')
      policy = config.merge('review' => review_policy('prompt_file' => 'review.md'))
      File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(policy))
      assert_equal 'partial', report(root, ref).status
      system('git', '-C', root, 'add', 'review.md', exception: true)
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_linked_worktree_uses_its_own_private_tree
    with_git_repository do |root|
      ref = commit_project(root)
      Dir.mktmpdir('shaka-linked') { |parent| assert_linked(root, ref, parent) }
    end
  end

  def test_normal_clone_discovers_its_own_git_directory
    with_private_repository do |root, ref|
      Dir.mktmpdir('shaka-clone') { |parent| assert_clone(root, ref, parent) }
    end
  end

  private

  def assert_linked(root, ref, parent)
    linked = File.join(parent, 'worktree')
    system('git', '-C', root, 'worktree', 'add', '--quiet', '--detach', linked, ref, exception: true)
    write_private_seam(linked)
    result = report(linked, ref)
    assert_equal 'complete', result.status
    assert_equal File.realpath(linked), result.root
    assert_equal File.realpath(File.join(root, '.git')), result.common_git_dir
    assert_equal 'absent', report(root, ref).status
  end

  def assert_clone(root, ref, parent)
    clone = File.join(parent, 'clone')
    system('git', 'clone', '--quiet', root, clone, exception: true)
    assert_equal 'absent', report(clone, ref).status
    write_private_seam(clone)
    result = report(clone, ref)
    assert_equal 'complete', result.status
    assert_equal File.realpath(File.join(clone, '.git')), result.common_git_dir
  end
end
