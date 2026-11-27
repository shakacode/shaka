# frozen_string_literal: true

require_relative 'install_scenario_support'

# The step that clears a default checkout's development removes its linked worktrees, so it is not printed
# while a skill link would be left pointing into one, and a failed Git read never offers to discard work.
# Status, the development refusal, and the refusal for an install into the worktree itself give the same step.
class InstallDevelopmentLinksTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps

  def test_a_host_link_into_a_worktree_skill_goes_to_a_person
    root, feature = default_with_worktree
    link = host_link('.claude/skills/shaka-dev', File.join(feature, 'skills/shaka'))
    assert_names_link(root, feature, link)
  end

  def test_a_link_to_the_worktree_root_goes_to_a_person
    root, feature = default_with_worktree
    link = host_link('.cursor/skills/feature', feature)
    assert_names_link(root, feature, link)
  end

  def test_a_skills_folder_linked_into_a_worktree_goes_to_a_person
    root, feature = default_with_worktree
    folder = File.join(@home, '.copilot/skills')
    FileUtils.mkdir_p(File.dirname(folder))
    File.symlink(File.join(feature, 'skills'), folder)
    assert_names_link(root, feature, folder)
  end

  # The link ends outside the worktree, but only through a symbolic link inside it, which removal deletes.
  def test_a_link_through_a_symlink_in_the_worktree_goes_to_a_person
    root, feature = default_with_worktree
    outside = File.join(@directory, 'outside')
    FileUtils.mkdir_p(outside)
    File.symlink(outside, File.join(feature, 'skills/escape'))
    link = host_link('.claude/skills/escape', File.join(feature, 'skills/escape'))
    assert_names_link(root, feature, link)
  end

  # Status cannot see a folder only this run names, so the installer checks it too.
  def test_a_requested_skills_folder_is_checked
    root, feature = default_with_worktree
    custom = File.join(@directory, 'custom-skills')
    FileUtils.mkdir_p(custom)
    File.symlink(File.join(feature, 'skills/shaka'), File.join(custom, 'shaka-dev'))
    assert_equal 'worktree remove', status(root)['next_command'][/worktree remove/]
    [refusal(root, '--skills-dir', custom), refusal(feature, '--directory', feature, '--skills-dir', custom)]
      .each { |output| assert_includes output, "Next: a person must decide where #{File.join(custom, 'shaka-dev')}" }
  end

  # Git cannot read a branch whose upstream names a blob; that proves nothing, so no command discards it.
  def test_a_failed_merge_read_is_not_unmerged_work
    root = default_install
    blob_upstream(root, 'feature')
    report = status(root)
    assert_nil report['next_command']
    assert_includes report['decision'], 'could not verify whether branch feature is merged'
    output = refusal(root)
    assert_includes output, 'could not verify whether branch feature is merged'
    refute_match(/branch -D|--force/, output)
  end

  private

  def default_with_worktree
    root = default_install
    feature = File.join(@directory, 'feature')
    git('-C', root, 'worktree', 'add', '-q', feature)
    [root, feature]
  end

  # A branch whose upstream ref names a blob, so git merge-base fails instead of answering.
  def blob_upstream(root, branch)
    git('-C', root, 'branch', branch)
    blob = git('-C', root, 'hash-object', '-w', File.join(root, 'bin/install')).strip
    git('-C', root, 'update-ref', "refs/remotes/origin/#{branch}", blob)
    git('-C', root, 'config', "branch.#{branch}.remote", 'origin')
    git('-C', root, 'config', "branch.#{branch}.merge", "refs/heads/#{branch}")
  end

  def host_link(relative, target)
    link = File.join(@home, relative)
    FileUtils.mkdir_p(File.dirname(link))
    File.symlink(target, link)
    link
  end

  def assert_names_link(root, feature, link)
    report = status(root)
    assert_equal 'C3', report['state']
    assert_nil report['next_command']
    expected = "a person must decide where #{link}"
    assert_includes report['decision'], expected
    [refusal(root), refusal(feature, '--directory', feature)].each do |output|
      assert_includes output, "Next: #{expected}"
      refute_includes output, 'worktree remove'
    end
  end
end
