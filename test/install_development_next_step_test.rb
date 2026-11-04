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
