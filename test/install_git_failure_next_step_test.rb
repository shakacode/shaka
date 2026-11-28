# frozen_string_literal: true

require_relative 'install_scenario_support'

# A clone or fetch that fails ends with a next command or a person's decision, never Git's own wording.
class InstallGitFailureNextStepTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps

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

  # ls-remote's pattern also matches ref names ending in it, so only the exact ref counts as the branch.
  def test_a_branch_that_only_ends_a_longer_name_is_missing
    git('-C', @root, 'push', '-q', @remote, 'HEAD:refs/heads/x/refs/heads/topic')
    output = refusal(@root, '--directory', File.join(@directory, 'new'), '--repository', @remote,
                     '--branch', 'topic', '--agent', 'claude')
    assert_includes git_words_free(output), "#{@remote} has no branch topic"
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
