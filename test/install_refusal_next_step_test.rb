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

  # A registered checkout's installer reinstalls itself without --directory, so its step names the empty folder.
  def test_maintenance_from_a_registered_checkout_names_the_empty_folder
    run_install(@root, '--directory', @root, '--repository', @remote)
    step = refused(@root, '--verify', '--directory', default_path)
    assert_includes step, "--directory #{Shellwords.escape(default_path)}"
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

  # The printed check runs from the new folder, as the clone did, so a relative repository names the same one.
  def test_a_mistyped_branch_into_a_new_folder_needs_a_person
    folder = File.join(@directory, 'new')
    output = refusal(@root, '--directory', folder, '--repository', '../remote.git', '--branch', 'mian',
                     '--agent', 'claude')
    assert_includes output, 'Next: a person must decide which branch to install; to list its branches, run git'
    assert_includes git_words_free(output), '../remote.git has no branch mian'
    assert_includes listed(output), 'refs/heads/main'
    installer(@root, '--directory', folder, '--repository', @remote, '--branch', 'main', '--agent', 'claude')
  end

  # The clone reads a hyphenated repository as a path, so the check after its failure must too.
  def test_a_failed_clone_never_reads_the_repository_as_an_option
    marker = File.join(@directory, 'ran')
    refusal(@root, '--directory', File.join(@directory, 'new'), '--repository', "--upload-pack=touch #{marker}",
            '--agent', 'claude')
    refute_path_exists marker
  end

  def test_an_update_that_cannot_reach_origin_names_the_check
    root, remote = install_from_copy
    File.rename(remote, "#{remote}.offline")
    output = git_words_free(refusal(root, '--update'))
    assert_includes output, "Installation could not download Shaka. Found: Git could not reach #{remote}"
    File.rename("#{remote}.offline", remote)
    assert_includes listed(output), 'refs/heads/main'
    installer(root, '--update')
  end

  private

  # An installation whose origin is its own copy of the fixture remote, so the test can take that copy away.
  def install_from_copy
    remote = File.join(@directory, 'away.git')
    git('clone', '-q', '--bare', @remote, remote)
    root = clone_to(File.join(@directory, 'installed'))
    git('-C', root, 'remote', 'set-url', 'origin', remote)
    run_install(root, '--directory', root, '--repository', remote)
    [root, remote]
  end

  # Git's own wording changes with version and locale, and "upstream" is a word users no longer see.
  def git_words_free(output)
    ['fatal:', 'upstream', 'Installation Git operation failed'].each { |words| refute_includes output, words }
    output
  end

  # Runs the ls-remote command a refusal names and returns what it lists.
  def listed(output)
    command = output[/(git -C \S+ ls-remote --heads -- \S+)/, 1]
    refute_nil command, output
    listing, process = Open3.capture2e(environment, 'sh', '-c', command)
    assert_predicate process, :success?, listing
    listing
  end
end
