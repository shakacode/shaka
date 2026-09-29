# frozen_string_literal: true

require_relative 'private_source_test'
require 'shaka/seam'

module PrivateSetupFixture
  include PrivateSourceFixture

  def with_setup
    with_git_repository do |root|
      commit_project(root)
      FileUtils.mkdir_p(File.join(root, 'bin'))
      File.write(File.join(root, 'bin/probe'), "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, File.join(root, 'bin/probe'))
      commit_file(root, 'bin/probe', 'add probe')
      yield root, head(root)
    end
  end

  def options
    { setup_command: 'bin/probe', validate_command: 'bin/probe', test_command: 'bin/probe',
      review_policy: 'none' }
  end

  def setup_private(root, ref) = Shaka::Seam::PrivateSetup.new(root:, ref:, options: options).setup
  def recovery(root) = Shaka::Seam::PrivateRecovery.new(root:)
  def config_path(root) = File.join(root, '.agents/shaka/config.yml')
  def copy_path(result) = File.join(result.fetch('recovery'), 'current/config.yml')

  def git(root, *)
    system('git', '-C', root, *, exception: true)
  end
end

class PrivateSetupTest < Minitest::Test
  include PrivateSetupFixture

  def test_setup_preserves_exclusion_and_local_authority
    with_setup do |root, ref|
      exclude = File.join(root, '.git/info/exclude')
      File.write(exclude, '# existing')
      result = setup_private(root, ref)
      assert_exclusion_and_copy(root, ref, exclude, result)
    end
  end

  def test_programmatic_options_cannot_grant_private_auto_or_fallback_checks
    with_setup do |root, ref|
      unsafe = options.merge(merge_preference: 'auto', required_checks: ['invented'])
      Shaka::Seam::PrivateSetup.new(root:, ref:, options: unsafe).setup
      config = Shaka::Configuration.private_source(root:, ref:).candidate_config
      assert_equal 'ask', config.merge.fetch('preference')
      refute config.merge.key?('required_checks')
    end
  end

  def test_cli_dispatches_setup_and_inspect
    with_setup do |root, ref|
      output, = capture_io { assert_equal 0, Shaka::Seam.run(cli_setup_args(root, ref)) }
      assert_equal 'complete', JSON.parse(output).fetch('status')
      output, = capture_io { assert_equal 0, Shaka::Seam.run(['private', 'inspect', '--root', root]) }
      assert_equal 'private', JSON.parse(output).fetch('status')
    end
  end

  def cli_setup_args(root, ref)
    ['private', 'setup', '--root', root, '--ref', ref,
     '--setup-command', 'bin/probe', '--validate-command', 'bin/probe',
     '--test-command', 'bin/probe', '--review-policy', 'none']
  end

  def assert_exclusion_and_copy(root, ref, exclude, result)
    assert_equal "# existing\n/.agents/shaka/\n", File.read(exclude)
    assert_equal '', Open3.capture2('git', '-C', root, 'status', '--porcelain').first
    assert_path_exists copy_path(result)
    config = Shaka::Configuration.private_source(root:, ref:).candidate_config
    assert_equal 'ask', config.merge.fetch('preference')
    refute config.merge.key?('required_checks')
  end

  def test_denied_exclusion_leaves_prepared_copy_for_retry
    with_setup do |root, ref|
      error = with_denied_exclusion { assert_raises(Shaka::Error) { setup_private(root, ref) } }
      assert_includes error.message, 'info/exclude'
      refute_path_exists File.join(root, '.agents/shaka')
      assert_path_exists File.join(recovery(root).storage, 'current/config.yml')
      assert_equal 'complete', setup_private(root, ref).fetch('status')
    end
  end

  def with_denied_exclusion
    original = File.method(:open)
    File.define_singleton_method(:open) do |path, *args, **kwargs, &block|
      raise Errno::EACCES, path if path.to_s.end_with?('info/exclude.shaka.lock')

      original.call(path, *args, **kwargs, &block)
    end
    yield
  ensure
    File.define_singleton_method(:open, original)
  end

  def test_interrupted_materialization_resumes
    with_setup do |root, ref|
      setup = Shaka::Seam::PrivateSetup.new(root:, ref:, options: options)
      context = self
      setup.define_singleton_method(:write_files) { |files| context.interrupt_after_first_file(files) }
      assert_raises(Shaka::Error) { setup.setup }
      assert_equal 'partial', recovery(root).inspect_checkout.fetch('status')
      assert_equal 'complete', setup_private(root, ref).fetch('status')
    end
  end

  def test_deferred_ci_wrappers_are_a_pair
    with_setup do |root, ref|
      partial = options.merge(validate_local_command: 'bin/probe')
      assert_raises(Shaka::Error) { Shaka::Seam::PrivateSetup.new(root:, ref:, options: partial).setup }
      complete = partial.merge(trigger_hosted_ci_command: 'bin/probe')
      result = Shaka::Seam::PrivateSetup.new(root:, ref:, options: complete).setup
      assert_equal 'complete', result.fetch('status')
      assert_path_exists File.join(root, '.agents/shaka/bin/validate-local')
      assert_path_exists File.join(root, '.agents/shaka/bin/trigger-hosted-ci')
    end
  end

  def interrupt_after_first_file(files)
    path, content = files.first
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    File.chmod(0o755, path)
    raise Errno::EIO, path
  end
end

class PrivateSetupFailureTest < Minitest::Test
  include PrivateSetupFixture

  def test_denied_recovery_write_reports_its_path
    with_setup do |root, ref|
      destination = recovery(root).storage
      with_denied_storage(destination) do
        error = assert_raises(Shaka::Error) { setup_private(root, ref) }
        assert_includes error.message, destination
      end
    end
  end

  def with_denied_storage(destination)
    original = FileUtils.method(:mkdir_p)
    FileUtils.define_singleton_method(:mkdir_p) do |path, **args|
      raise Errno::EACCES, path if path == destination

      original.call(path, **args)
    end
    yield
  ensure
    FileUtils.define_singleton_method(:mkdir_p, original)
  end
end

class PrivateRecoveryTest < Minitest::Test
  include PrivateSetupFixture

  def test_linked_worktrees_keep_distinct_copies_after_deletion
    with_setup do |root, ref|
      linked = "#{root}-linked"
      first, second = setup_linked_copies(root, ref, linked)
      assert_linked_isolation(root, first, second)
      assert_sibling_restore_refused(root, linked, second)
      assert_deleted_recovery(root, linked, second)
      assert_recreated_worktree_is_new(root, ref, linked, second)
    ensure
      git(root, 'worktree', 'remove', '--force', linked) if File.exist?(linked)
    end
  end

  def assert_recreated_worktree_is_new(root, ref, linked, old)
    git(root, 'worktree', 'add', '--quiet', '-b', 'linked-again', linked)
    fresh = setup_private(linked, ref)
    refute_equal old.fetch('recovery'), fresh.fetch('recovery')
    assert_path_exists File.join(old.fetch('recovery'), 'current/local-note')
    assert_equal 3, recovery(root).list.length
  end

  def assert_deleted_recovery(root, linked, result)
    git(root, 'worktree', 'remove', '--force', linked)
    assert_deleted_worktree_restore(root, result)
    File.delete(File.join(result.fetch('recovery'), 'manifest.json'))
    assert_equal 2, recovery(root).list.length
  end

  def assert_sibling_restore_refused(root, linked, result)
    git(linked, 'clean', '-fdx')
    id = File.basename(result.fetch('recovery'))
    assert_raises(Shaka::Error) { recovery(root).restore(id:, to: File.join(linked, '.agents/shaka')) }
  end

  def assert_deleted_worktree_restore(root, result)
    id = File.basename(result.fetch('recovery'))
    inspection = "#{root}-deleted-inspection"
    recovery(root).restore(id:, to: inspection)
    assert_equal 'linked only', File.read(File.join(inspection, 'local-note'))
  ensure
    FileUtils.rm_rf(inspection) if inspection
  end

  def setup_linked_copies(root, ref, linked)
    git(root, 'worktree', 'add', '--quiet', '-b', 'linked', linked)
    first = setup_private(root, ref)
    second = setup_private(linked, ref)
    File.write(File.join(linked, '.agents/shaka/local-note'), 'linked only')
    recovery(linked).inspect_checkout
    [first, second]
  end

  def assert_linked_isolation(root, first, second)
    refute_equal first.fetch('recovery'), second.fetch('recovery')
    refute_path_exists File.join(first.fetch('recovery'), 'current/local-note')
    assert_equal 'linked only', File.read(File.join(second.fetch('recovery'), 'current/local-note'))
    assert_equal 1, File.read(File.join(root, '.git/info/exclude')).scan('/.agents/shaka/').length
  end

  def test_git_clean_keeps_copy_and_adoption_restore_only_compares
    with_setup do |root, ref|
      result = setup_private(root, ref)
      config = config_path(root)
      change_private_preference(root)
      assert_previous_copy(result)
      assert_clean_preserves_edited_copy(root, ref, result, config)
      assert_comparison_restore(root, result)
    end
  end

  def assert_clean_preserves_edited_copy(root, ref, result, config)
    git(root, 'clean', '-fdx')
    refute_path_exists config
    assert_raises(Shaka::Error) { setup_private(root, ref) }
    assert_includes File.read(copy_path(result)), 'preference: auto'
  end

  def change_private_preference(root)
    config = config_path(root)
    File.write(config, File.read(config).sub('preference: ask', 'preference: auto'))
    recovery(root).inspect_checkout
  end

  def assert_previous_copy(result)
    previous = File.join(result.fetch('recovery'), 'previous/config.yml')
    assert_includes File.read(previous), 'preference: ask'
  end

  def assert_comparison_restore(root, result)
    stage_team_adoption(root)
    assert_equal 'adopted', recovery(root).inspect_checkout.fetch('status')
    inspection = "#{root}-inspection"
    recovery(root).restore(to: inspection)
    assert_restored_copy(root, result, inspection)
  ensure
    FileUtils.rm_rf(inspection) if inspection
  end

  def assert_restored_copy(root, result, inspection)
    assert_equal File.read(copy_path(result)), File.read(File.join(inspection, 'config.yml'))
    assert_equal "team: true\n", File.read(config_path(root))
    assert_raises(Shaka::Error) { recovery(root).restore(to: File.join(root, '.agents/shaka')) }
  end

  def stage_team_adoption(root)
    config = config_path(root)
    FileUtils.mkdir_p(File.dirname(config))
    File.write(config, "team: true\n")
    git(root, 'add', '-f', '.agents/shaka/config.yml')
  end
end

class PrivateAdoptionTest < Minitest::Test
  include PrivateSetupFixture

  def test_outside_merge_overwrites_ignored_file_but_keeps_copy
    with_setup do |root, ref|
      result = setup_private(root, ref)
      File.write(config_path(root), "personal: before pull\n")
      recovery(root).inspect_checkout
      adopt_from_team_branch(root)
      assert_adoption_preserves_copy(root, result)
    end
  end

  def test_staged_partial_adoption_does_not_refresh_private_copy
    with_setup do |root, ref|
      result = setup_private(root, ref)
      git(root, 'add', '-f', '.agents/shaka/bin/setup')
      File.write(config_path(root), "edited after adoption\n")
      report = recovery(root).inspect_checkout
      assert_equal 'adopted', report.fetch('status')
      assert_includes report.fetch('adoption_paths'), '.agents/shaka/bin/setup'
      refute_includes File.read(copy_path(result)), 'edited after adoption'
    end
  end

  def assert_adoption_preserves_copy(root, result)
    assert_equal "team: after pull\n", File.read(config_path(root))
    report = recovery(root).inspect_checkout
    assert_equal 'adopted', report.fetch('status')
    assert_includes report.fetch('changed'), 'config.yml'
    assert_includes report.fetch('hidden_untracked'), '.agents/shaka/bin/setup'
    assert_equal "personal: before pull\n", File.read(copy_path(result))
  end

  def adopt_from_team_branch(root)
    branch = Open3.capture2('git', '-C', root, 'branch', '--show-current').first.strip
    git(root, 'checkout', '-q', '-b', 'team')
    File.write(config_path(root), "team: after pull\n")
    git(root, 'add', '-f', '.agents/shaka/config.yml')
    git(root, 'commit', '-qm', 'team adopts Shaka')
    git(root, 'checkout', '-q', branch)
    File.write(config_path(root), "personal: before pull\n")
    git(root, 'merge', '--ff-only', 'team')
  end
end
