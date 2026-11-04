# frozen_string_literal: true

require_relative 'install_scenario_support'

# Each installer refusal ends with a next command that clears it, or says a person must decide.
class InstallRefusalNextStepTest < Minitest::Test
  include InstallScenarioSupport

  def test_a_writable_checkout_names_the_chmod_that_clears_it
    root = default_install
    File.chmod(0o775, root)
    step = refused(root, '--verify')
    assert_includes step, 'chmod go-w '
    run_step(step)
    installer(root, '--verify')
  end

  def test_maintenance_without_an_install_names_the_installer
    step = refused(@root, '--verify')
    assert_equal Shellwords.escape(File.join(@root, 'bin/install')), step
  end

  def test_local_commits_get_the_step_that_keeps_them_on_a_branch
    root = default_install
    commit(root, 'local change')
    step = refused(root, '--verify')
    assert_includes step, 'reset --keep'
    run_step(step)
    installer(root, '--verify')
    refute_empty git('-C', root, 'for-each-ref', '--format=%(refname:short)', 'refs/heads/kept-*').strip
  end

  def test_a_linked_worktree_keeps_the_selected_agent
    worktree = File.join(@directory, 'worktree')
    git('-C', @root, 'worktree', 'add', '-q', '--detach', worktree)
    step = refused(worktree, '--directory', worktree, '--repository', @remote, '--agent', 'claude')
    assert_includes step, '--agent claude'
    run_step(step)
    assert_equal File.join(File.realpath(default_path), 'skills/shaka'),
                 File.realpath(File.join(@home, '.claude/skills/shaka'))
  end

  def test_a_missing_branch_needs_a_person
    output = refusal(default_install, '--branch', 'mian')
    refute_includes output, 'switch mian'
    assert_includes output, 'Next: a person must decide'
  end

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

  def installer(root, *)
    output, process = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), *)
    assert_predicate process, :success?, output
    output
  end

  def refusal(root, *)
    output, process = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), *)
    refute_predicate process, :success?, output
    output
  end

  # The command after the last "Next: ", which every installer refusal ends with.
  def refused(root, *)
    output = refusal(root, *)
    step = output[/.*Next: (.+?)\.?\s*\z/m, 1]
    refute_nil step, output
    refute_match(/\Aa person must decide/, step, output)
    step
  end

  def run_step(step)
    output, process = Open3.capture2e(environment, 'sh', '-c', step)
    assert_predicate process, :success?, output
  end
end
