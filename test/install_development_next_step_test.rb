# frozen_string_literal: true

require_relative 'install_scenario_support'

# A checkout at the default location that hosts development cannot hand its hosts to a fresh checkout
# there, so it gets the commands that clear the development, or a decision naming work found nowhere else.
class InstallDevelopmentNextStepTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps

  def test_a_default_checkout_with_a_merged_worktree_clears_it_with_printed_commands
    root = default_install
    git('-C', root, 'worktree', 'add', '-q', File.join(@directory, 'feature'))
    step = refused(root)
    refute_includes step, '--take-over'
    assert_includes step, 'worktree remove'
    report = status(root)
    assert_equal step, report['next_command']
    run_next(report, 'C3')
    assert_equal 'ok', status(root)['severity']
  end

  # Git never prunes a locked worktree, so one whose folder is gone stays listed and needs a person.
  def test_a_locked_worktree_with_a_missing_folder_still_verifies
    root = default_install
    worktree = File.join(@directory, 'portable')
    git('-C', root, 'worktree', 'add', '-q', worktree)
    git('-C', root, 'worktree', 'lock', worktree)
    FileUtils.rm_rf(worktree)
    assert_includes installer(root, '--verify'), 'Warning:'
    assert_match(/a person must decide .*locked worktree/, status(root)['decision'])
  end

  # git worktree remove deletes ignored files, such as a local .env, so they are work a person decides on.
  def test_a_worktree_holding_only_an_ignored_file_needs_a_person
    root = default_install
    worktree = File.join(@directory, 'feature')
    git('-C', root, 'worktree', 'add', '-q', worktree)
    File.write(File.join(root, '.git/info/exclude'), ".env\n")
    File.write(File.join(worktree, '.env'), 'TOKEN=local')
    assert_match(/a person must decide .*uncommitted files/, status(root)['decision'])
  end

  # Worktree paths are read NUL-separated, so a newline in one still gets a command that removes it.
  def test_a_worktree_path_with_a_newline_is_cleared
    root = default_install
    git('-C', root, 'worktree', 'add', '-q', '-b', 'feature', File.join(@directory, "feature\nextra"))
    run_next(status(root), 'C3')
    assert_equal 'ok', status(root)['severity']
  end

  # A worktree folder deleted by hand still holds its branch until Git prunes it.
  def test_a_deleted_worktree_folder_is_pruned_before_its_branch_goes
    root = default_install
    worktree = File.join(@directory, 'feature')
    git('-C', root, 'worktree', 'add', '-q', worktree)
    FileUtils.rm_rf(worktree)
    report = status(root)
    assert_includes report['next_command'], 'worktree prune'
    run_next(report, 'C3')
    assert_equal 'ok', status(root)['severity']
  end

  # git worktree remove refuses a worktree with submodules, even on a branch merged into the one it tracks.
  def test_a_default_checkout_worktree_with_a_submodule_needs_a_person
    root = default_install
    pushed_submodule_branch(root, File.join(@directory, 'feature'))
    report = status(root)
    assert_nil report['next_command']
    assert_match(/a person must decide .*submodules/, report['decision'])
  end

  # The B2 step keeps local commits on a branch, which then needs a person, not a failing take-over.
  def test_a_default_checkout_with_unmerged_work_names_it_for_a_person
    root = default_install
    commit(root, 'local change')
    run_next(status(root), 'B2')
    report = status(root)
    assert_equal 'C3', report['state']
    assert_nil report['next_command']
    assert_match(/a person must decide .*kept-/, report['decision'])
  end

  def test_installing_a_switched_branch_at_the_default_path_clears_the_old_branch
    root = clone_to(default_path)
    git('-C', root, 'switch', '-q', '-c', 'feature')
    git('-C', root, 'push', '-qu', 'origin', 'feature')
    flags = ['--directory', root, '--repository', @remote, '--branch', 'feature']
    step = refused(root, *flags)
    assert_includes step, 'branch -d main'
    run_step(step)
    installer(root, *flags)
  end

  private

  # A pushed branch, tracked and fully merged into origin's copy, whose worktree holds a submodule.
  def pushed_submodule_branch(root, worktree)
    git('-C', root, 'worktree', 'add', '-q', '-b', 'feature', worktree)
    head = git('-C', worktree, 'rev-parse', 'HEAD').strip
    git('-C', worktree, 'update-index', '--add', '--cacheinfo', "160000,#{head},vendor/module")
    FileUtils.mkdir_p(File.join(worktree, 'vendor/module'))
    git('-C', worktree, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'module')
    git('-C', worktree, 'push', '-qu', @remote, 'feature:feature')
    git('-C', worktree, 'fetch', '-q', @remote, '+feature:refs/remotes/origin/feature')
    git('-C', worktree, 'branch', '-q', '-u', 'origin/feature')
  end
end
