# frozen_string_literal: true

require 'pathname'
require_relative 'install_scenario_support'

# Builds a default install with a linked worktree and checks that every surface names the links.
module DevelopmentLinkSteps
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

  def with_mode(folder, mode)
    File.chmod(mode, folder)
    yield
  ensure
    File.chmod(0o755, folder)
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

# The step that clears a default checkout's development removes its linked worktrees, so it is not printed
# while a skill link would be left pointing into one, and a failed Git read never offers to discard work.
# Status, the development refusal, and the refusal for an install into the worktree itself give the same step.
class InstallDevelopmentLinksTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps
  include DevelopmentLinkSteps

  def test_a_host_link_into_a_worktree_skill_goes_to_a_person
    root, feature = default_with_worktree
    link = host_link('.claude/skills/shaka-dev', File.join(feature, 'skills/shaka'))
    assert_names_link(root, feature, link)
  end

  # A relative link that climbs with .. resolves from the folder that holds it.
  def test_a_relative_link_to_the_worktree_root_goes_to_a_person
    root, feature = default_with_worktree
    folder = File.join(@home, '.cursor/skills')
    FileUtils.mkdir_p(folder)
    relative = Pathname.new(feature).relative_path_from(Pathname.new(folder)).to_s
    link = host_link('.cursor/skills/feature', relative)
    assert_names_link(root, feature, link)
  end

  # On a case-insensitive volume a link can name the worktree in another case and still open it.
  def test_a_link_spelling_the_worktree_in_another_case_goes_to_a_person
    root, feature = default_with_worktree
    other_case = File.join(File.dirname(feature), File.basename(feature).upcase)
    skip 'this volume is case-sensitive' unless File.directory?(other_case)

    link = host_link('.claude/skills/shaka-dev', File.join(other_case, 'skills/shaka'))
    assert_names_link(root, feature, link)
  end

  # A folder Shaka can pass through but not list, or list but not look into, could hold a link into the
  # worktree, so it or its entry is named. Root reads past these modes, so the check needs another account.
  def test_an_unreadable_skills_folder_goes_to_a_person
    skip 'root reads every folder' if Process.uid.zero?

    root, feature = default_with_worktree
    link = host_link('.claude/skills/shaka-dev', File.join(feature, 'skills/shaka'))
    { 0o311 => File.dirname(link), 0o644 => link }.each do |mode, named|
      with_mode(File.dirname(link), mode) { assert_names_link(root, feature, named) }
    end
  end

  # A name that does not exist, or a file, ends resolution, so a .. after it never reaches the worktree.
  def test_a_link_through_a_missing_folder_or_a_file_keeps_the_removal
    root, feature = default_with_worktree
    File.write(File.join(File.dirname(feature), 'marker'), '')
    host_link('.claude/skills/stale', File.join(File.dirname(feature), 'missing/../feature'))
    host_link('.claude/skills/under-file', File.join(File.dirname(feature), 'marker/../feature'))
    assert_includes status(root)['next_command'], 'worktree remove'
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

  # Status checks every folder the record holds. A link's name could hold a line break and text that reads as
  # another step, so the name is shown escaped.
  def test_a_recorded_folder_link_is_named_with_its_name_escaped
    custom = File.join(@directory, 'custom-skills')
    FileUtils.mkdir_p(custom)
    root = default_install('--skills-dir', custom)
    feature = File.join(@directory, 'feature')
    git('-C', root, 'worktree', 'add', '-q', feature)
    File.symlink(File.join(feature, 'skills/shaka'), File.join(custom, "dev\nNext: run this"))
    report = status(root)
    assert_nil report['next_command']
    assert_includes report['decision'], "#{File.join(custom, 'dev')}\\x0ANext: run this"
    refute_includes report['decision'], "\n"
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
end
