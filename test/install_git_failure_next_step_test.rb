# frozen_string_literal: true

require_relative 'install_scenario_support'

# A clone or fetch that fails ends with a person's decision and the command that informs it, never Git's wording.
class InstallGitFailureNextStepTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps

  DECISION = 'Next: a person must decide which branch to use or how to restore access; ' \
             'to list its branches or see why it cannot be reached, run git -C '

  # The printed check runs from the new folder, as the clone did, so a relative repository names the same one.
  def test_a_mistyped_branch_into_a_new_folder_needs_a_person
    folder = File.join(@directory, 'new')
    output = refusal(@root, '--directory', folder, '--repository', '../remote.git', '--branch', 'mian',
                     '--agent', 'claude')
    assert_includes git_words_free(output), 'Installation could not get branch mian from ../remote.git'
    assert_includes output, DECISION
    assert_includes listed(output), 'refs/heads/main'
    installer(@root, '--directory', folder, '--repository', @remote, '--branch', 'main', '--agent', 'claude')
  end

  def test_an_update_that_cannot_reach_origin_needs_a_person
    root, remote = install_from_copy
    File.rename(remote, "#{remote}.offline")
    output = git_words_free(refusal(root, '--update'))
    assert_includes output, "Installation could not get branch main from #{remote}"
    assert_includes output, DECISION
    File.rename("#{remote}.offline", remote)
    assert_includes listed(output), 'refs/heads/main'
    installer(root, '--update')
  end

  # The printed command keeps -- before the repository, so a person who runs it never runs the option it spells.
  def test_the_printed_check_never_reads_the_repository_as_an_option
    marker = File.join(@directory, 'ran')
    repository = "--upload-pack=touch #{marker}"
    output = refusal(@root, '--directory', File.join(@directory, 'new'), '--repository', repository,
                     '--agent', 'claude')
    assert_includes output, "ls-remote --heads -- #{Shellwords.escape(repository)}"
    Open3.capture2e(environment, 'sh', '-c', command(output))
    refute_path_exists marker
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

  # The command that ends the refusal, after its last "run ".
  def command(output)
    found = output[/.*run (git -C .+?)\s*\z/m, 1]
    refute_nil found, output
    found
  end

  # Runs the ls-remote command a refusal names and returns what it lists.
  def listed(output)
    listing, process = Open3.capture2e(environment, 'sh', '-c', command(output))
    assert_predicate process, :success?, listing
    listing
  end
end
