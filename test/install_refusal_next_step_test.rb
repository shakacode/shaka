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
    writable = Shaka::Install::DirectorySafety::WRITABLE
    message = "Installation directory is unsafe: / #{writable}"
    error = assert_raises(ArgumentError) { safety.send(:refuse_unsafe, message, writable, '/', File.lstat('/')) }
    refute_kind_of Shaka::Install::DirectorySafety::Unsafe, error
    assert_equal message, error.message
  end

  # Selections belong to bin/install, so maintenance with one is refused before any install step is built.
  def test_maintenance_with_a_selection_is_refused_first
    assert_includes refusal(@root, '--verify', '--repository', @remote, '--agent', 'claude'),
                    'Use bin/install to change installation selections before maintenance'
  end

  # A branch only origin has is switched to by its full name, so another remote's copy cannot make it ambiguous.
  # git branch refuses a kept name already in use, so a kept branch moved elsewhere needs a person.
  def test_local_commits_with_an_occupied_kept_branch_need_a_person
    root = default_install
    commit(root, 'local change')
    name = "kept-#{git('-C', root, 'rev-parse', '--short', 'HEAD').strip}"
    git('-C', root, 'branch', name, 'HEAD~1')
    assert_includes refusal(root, '--verify'), 'Next: a person must decide where to keep these commits, because ' \
                                               "branch #{name}"
    report = status(root)
    assert_equal 'B2', report['state']
    assert_nil report['next_command']
  end

  # A checkout reset behind its record catches up with a fast-forward.
  def test_a_checkout_behind_its_record_fast_forwards
    root = default_install
    pull(root)
    head = record_head(root)
    git('-C', root, 'reset', '-q', '--hard', 'HEAD~1')
    step = refused(root, '--verify')
    assert_includes step, 'merge --ff-only'
    run_step(step)
    assert_equal head, git('-C', root, 'rev-parse', 'HEAD').strip
  end

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

  # When origin's history was rewritten, which history to keep is a person's choice, as status says.
  def test_a_rewritten_origin_needs_a_person
    root = default_install
    commit(@root, 'rewritten', amend: true)
    git('-C', @root, 'push', '--force', '-q', 'origin', 'main')
    git('-C', root, 'fetch', '-q', @remote, '+main:refs/remotes/origin/main')
    git('-C', root, 'reset', '-q', '--hard', 'origin/main')
    output = refusal(root, '--verify')
    refute_includes output, 'reset --keep'
    assert_includes output, 'Next: a person must decide which revision main should use'
  end

  def test_a_missing_branch_needs_a_person
    output = refusal(default_install, '--branch', 'mian')
    refute_includes output, 'switch mian'
    assert_includes output, 'Next: a person must decide'
  end

  private

  # Points the install record at HEAD and returns it.
  def record_head(root)
    head = git('-C', root, 'rev-parse', 'HEAD').strip
    record = File.join(root, '.git/shaka-install.json')
    File.write(record, JSON.generate(JSON.parse(File.read(record)).merge('revision' => head)))
    head
  end
end
