# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'configuration_layout_fixture'
require 'shaka/configuration'
require 'pp'

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

  def write_review_prompt_policy(root)
    policy = config.merge('review' => review_policy('prompt_file' => 'review.md'))
    File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(policy))
  end

  def commit_file(root, path, message)
    system('git', '-C', root, 'add', path, exception: true)
    system('git', '-C', root, 'commit', '--quiet', '-m', message, exception: true)
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

  def test_legacy_only_checkout_has_no_private_source
    with_git_repository do |root|
      ref = commit_project(root)
      FileUtils.mkdir_p(File.join(root, '.agents'))
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
      assert_equal 'absent', report(root, ref).status
    end
  end

  def test_trusted_legacy_policy_does_not_become_private
    with_git_repository do |root|
      commit_project(root)
      FileUtils.mkdir_p(File.join(root, '.agents'))
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
      system('git', '-C', root, 'add', '.agents/agent-workflow.yml', exception: true)
      system('git', '-C', root, 'commit', '--quiet', '-m', 'team seam', exception: true)
      result = report(root, head(root))
      assert_equal 'absent', result.status
      assert_equal 'present', result.trusted_source
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
      write_review_prompt_policy(root)
      assert_equal 'partial', report(root, ref).status
    end
  end

  def test_staged_prompt_needs_a_commit
    with_private_repository do |root, ref|
      File.write(File.join(root, 'review.md'), 'private prompt')
      write_review_prompt_policy(root)
      system('git', '-C', root, 'add', 'review.md', exception: true)
      assert_equal 'partial', report(root, ref).status
      system('git', '-C', root, 'commit', '--quiet', '-m', 'review prompt', exception: true)
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_external_prompt_symlink_must_itself_be_committed
    with_private_repository do |root, ref|
      File.write(File.join(root, 'shared-review.md'), 'tracked prompt')
      commit_file(root, 'shared-review.md', 'shared prompt')
      File.symlink('shared-review.md', File.join(root, 'review.md'))
      write_review_prompt_policy(root)
      assert_equal 'partial', report(root, ref).status
      commit_file(root, 'review.md', 'prompt link')
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_missing_prompt_is_partial
    with_private_repository do |root, ref|
      write_review_prompt_policy(root)
      assert_equal 'partial', report(root, ref).status
    end
  end

  def test_missing_internal_prompt_is_partial
    with_private_repository do |root, ref|
      policy = config.merge('review' => review_policy('prompt_file' => '.agents/shaka/review.md'))
      File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(policy))
      assert_equal 'partial', report(root, ref).status
    end
  end
end

class PrivateSourceWorktreeTest < Minitest::Test
  include PrivateSourceFixture

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

class PrivateSourceBoundaryTest < Minitest::Test
  include PrivateSourceFixture

  def test_committed_private_config_conflicts_even_after_index_removal
    with_private_repository do |root, ref|
      path = '.agents/shaka/config.yml'
      system('git', '-C', root, 'add', path, exception: true)
      system('git', '-C', root, 'commit', '--quiet', '-m', 'private config', exception: true)
      system('git', '-C', root, 'rm', '--cached', '--quiet', path, exception: true)
      assert_equal 'conflicting', report(root, ref).status
    end
  end

  def test_regular_file_at_private_directory_is_unsafe
    with_git_repository do |root|
      ref = commit_project(root)
      FileUtils.mkdir_p(File.join(root, '.agents'))
      File.write(File.join(root, '.agents/shaka'), 'not a directory')
      assert_equal 'unsafe_file', report(root, ref).status
    end
  end

  def test_result_display_does_not_include_candidate_config
    with_private_repository do |root, ref|
      result = report(root, ref)
      refute_includes result.inspect, 'candidate_config'
      refute_includes result.to_s, 'RepositoryConfig'
      refute_includes PP.pp(result, +''), 'candidate_config'
    end
  end

  def test_symlinked_agents_root_is_unsafe
    with_git_repository do |root|
      ref = commit_project(root)
      File.symlink('elsewhere', File.join(root, '.agents'))
      assert_equal 'unsafe_file', report(root, ref).status
    end
  end

  def test_symlinked_private_root_has_one_unsafe_blocker
    with_git_repository do |root|
      ref = commit_project(root)
      FileUtils.mkdir_p(File.join(root, '.agents'))
      FileUtils.mkdir_p(File.join(root, 'elsewhere'))
      File.symlink('../elsewhere', File.join(root, '.agents/shaka'))
      result = report(root, ref)
      assert_equal 'unsafe_file', result.status
      assert_equal 1, result.blockers.size
    end
  end

  def test_tracked_submodule_at_private_root_conflicts
    with_private_repository do |root, ref|
      system('git', '-C', root, 'update-index', '--add', '--cacheinfo', '160000', ref, '.agents/shaka', exception: true)
      assert_equal 'conflicting', report(root, ref).status
    end
  end

  def test_tracked_submodule_at_agents_ancestor_conflicts
    with_private_repository do |root, ref|
      system('git', '-C', root, 'update-index', '--add', '--cacheinfo', '160000', ref, '.agents', exception: true)
      assert_equal 'conflicting', report(root, ref).status
    end
  end

  def test_case_alias_for_tracked_private_tree_conflicts
    with_private_repository do |root, ref|
      lower = File.join(root, '.agents/shaka')
      upper = File.join(root, '.agents/Shaka')
      skip 'case-sensitive filesystem' unless File.identical?(lower, upper)

      blob = Open3.capture2('git', '-C', root, 'hash-object', '-w', File.join(lower, 'config.yml')).first.strip
      system('git', '-C', root, 'update-index', '--add', '--cacheinfo', '100644', blob,
             '.agents/Shaka/config.yml', exception: true)
      assert_equal 'conflicting', report(root, ref).status
    end
  end

  def test_external_symlink_target_must_be_committed
    with_private_repository do |root, ref|
      File.write(File.join(root, 'helper.sh'), "#!/bin/sh\n")
      File.symlink('../../../helper.sh', File.join(root, '.agents/shaka/bin/extra'))
      assert_equal 'partial', report(root, ref).status
      system('git', '-C', root, 'add', 'helper.sh', exception: true)
      system('git', '-C', root, 'commit', '--quiet', '-m', 'helper', exception: true)
      assert_equal 'complete', report(root, ref).status
    end
  end
end

class PrivateSourceSymlinkChainTest < Minitest::Test
  include PrivateSourceFixture

  def test_prompt_through_committed_directory_symlink_is_complete
    with_private_repository do |root, ref|
      create_directory_prompt(root)
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_committed_prompt_link_into_private_tree_is_complete
    with_private_repository do |root, ref|
      File.write(File.join(root, '.agents/shaka/review.md'), 'prompt')
      File.symlink('.agents/shaka/review.md', File.join(root, 'review.md'))
      write_review_prompt_policy(root)
      commit_file(root, 'review.md', 'prompt link')
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_private_command_requires_every_external_hop_committed
    with_private_repository do |root, ref|
      create_chain(root, final: 'final.sh', middle: 'middle.sh', first: nil, content: "#!/bin/sh\n")
      File.symlink('../../../middle.sh', File.join(root, '.agents/shaka/bin/extra'))
      result = report(root, ref)
      assert_equal 'partial', result.status
      assert_includes result.blockers.join(' '), 'middle.sh'
      commit_file(root, 'middle.sh', 'middle link')
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_external_prompt_requires_every_hop_committed
    with_private_repository do |root, ref|
      create_chain(root, final: 'final.md', middle: 'middle.md', first: 'review.md', content: 'prompt')
      write_review_prompt_policy(root)
      assert_equal 'partial', report(root, ref).status
      commit_file(root, 'middle.md', 'middle link')
      assert_equal 'complete', report(root, ref).status
    end
  end

  def test_prompt_link_that_leaves_and_reenters_worktree_is_partial
    with_private_repository do |root, ref|
      File.write(File.join(root, 'shared.md'), 'prompt')
      File.symlink("../#{File.basename(root)}/shared.md", File.join(root, 'review.md'))
      write_review_prompt_policy(root)
      commit_file(root, 'shared.md', 'shared prompt')
      commit_file(root, 'review.md', 'prompt link')
      assert_equal 'partial', report(root, ref).status
    end
  end

  def test_private_link_that_leaves_and_reenters_worktree_is_unsafe
    with_private_repository do |root, ref|
      File.write(File.join(root, 'shared.sh'), "#!/bin/sh\n")
      File.symlink("../../../../#{File.basename(root)}/shared.sh", File.join(root, '.agents/shaka/bin/extra'))
      assert_equal 'unsafe_file', report(root, ref).status
    end
  end

  private

  def create_directory_prompt(root)
    FileUtils.mkdir_p(File.join(root, 'internal'))
    File.write(File.join(root, 'internal/review.md'), 'prompt')
    File.symlink('internal', File.join(root, 'docs'))
    policy = config.merge('review' => review_policy('prompt_file' => 'docs/review.md'))
    File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(policy))
    commit_file(root, 'internal/review.md', 'prompt')
    commit_file(root, 'docs', 'directory link')
  end

  def create_chain(root, final:, middle:, first:, content:)
    File.write(File.join(root, final), content)
    File.symlink(final, File.join(root, middle))
    File.symlink(middle, File.join(root, first)) if first
    commit_file(root, final, 'final file')
    commit_file(root, first, 'first link') if first
  end
end

class PrivateSourceInputTest < Minitest::Test
  include PrivateSourceFixture

  def test_result_hash_uses_string_keys_for_inventory_entries
    with_private_repository do |root, ref|
      result = report(root, ref)
      assert_equal '.agents/shaka', result.to_h.dig('inventory', 0, 'path')
      refute result.to_h.fetch('inventory').first.key?(:path)
    end
  end

  def test_unreadable_config_is_reported_as_partial
    with_private_repository do |root, ref|
      path = File.join(root, '.agents/shaka/config.yml')
      File.chmod(0, path)
      expected = File.readable?(path) ? 'complete' : 'partial'
      assert_equal expected, report(root, ref).status
    ensure
      File.chmod(0o644, path)
    end
  end

  def test_unrelated_non_utf8_git_path_does_not_abort_inventory
    with_private_repository do |root, ref|
      resolver = Class.new(Shaka::Configuration::PrivateSource) do
        private

        def git(*args)
          output = super
          %w[ls-files ls-tree].include?(args.first) ? output.b + "odd-\xFF\0".b : output
        end
      end
      assert_equal 'complete', resolver.new(root:, ref:).resolve.status
    end
  end
end
