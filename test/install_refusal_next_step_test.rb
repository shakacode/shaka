# frozen_string_literal: true

require_relative 'install_scenario_support'
require_relative '../skills/shaka/lib/shaka/install/directory_safety'

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

  # chmod needs the directory's owner, so a writable directory root owns gets no chmod step.
  def test_a_writable_directory_root_owns_gets_no_chmod
    safety = Class.new { include Shaka::Install::DirectorySafety }.new
    error = assert_raises(ArgumentError) do
      safety.send(:refuse_unsafe, "Installation directory is unsafe: / #{Shaka::Install::DirectorySafety::WRITABLE}",
                  '/', File.lstat('/'))
    end
    refute_kind_of Shaka::Install::DirectorySafety::Unsafe, error
  end

  # Selections belong to bin/install, so maintenance with one is refused before any install step is built.
  def test_maintenance_with_a_selection_is_refused_first
    assert_includes refusal(@root, '--verify', '--repository', @remote, '--agent', 'claude'),
                    'Use bin/install to change installation selections before maintenance'
  end

  # A branch only origin has is switched to by its full name, so another remote's copy cannot make it ambiguous.
  def test_a_branch_only_origin_has_switches_by_its_full_name
    root = default_install
    git('-C', root, 'push', '-q', @remote, 'HEAD:refs/heads/topic')
    git('-C', root, 'fetch', '-q', @remote, '+topic:refs/remotes/origin/topic', '+topic:refs/remotes/mirror/topic')
    git('-C', root, 'remote', 'add', 'mirror', @remote)
    step = refused(root, '--branch', 'topic')
    assert_includes step, 'switch --track origin/topic'
    run_step(step)
    assert_equal 'topic', git('-C', root, 'branch', '--show-current').strip
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
