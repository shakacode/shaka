# frozen_string_literal: true

require_relative 'install_scenario_support'

# Each installer refusal ends with a next command that clears it, or says a person must decide.
class InstallRefusalNextStepTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps

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
end
