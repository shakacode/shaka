# frozen_string_literal: true

# Installing into a worktree of the registered install leaves removal to a person whenever it would lose
# something: a link into a worktree, uncommitted work, or control of an unsafe owner (#1284).
module OwnedWorktreeScenarios
  # A link that resolves into the worktree would break with it, so removal is left to a person.
  def test_an_owned_worktree_serving_a_link_goes_to_a_person
    _root, feature = owned_worktree
    link = File.join(@home, '.agents/skills/shaka')
    File.unlink(link)
    File.symlink(File.join(feature, 'skills/shaka'), link)
    output = refusal(feature, '--directory', feature)
    assert_match(/Next: a person must decide where the skills links \S*shaka should point; they resolve into/, output)
    assert_path_exists feature
  end

  # A link to the worktree itself counts as one into it.
  def test_an_owned_worktree_serving_a_requested_skills_folder_goes_to_a_person
    _root, feature = owned_worktree
    custom = File.join(@directory, 'custom-skills')
    FileUtils.mkdir_p(custom)
    File.symlink(feature, File.join(custom, 'shaka'))
    output = refusal(feature, '--directory', feature, '--skills-dir', custom)
    assert_includes output, "Next: a person must decide where the skills links #{custom}/shaka"
  end

  # The removal step clears every worktree the install hosts, so a link into a sibling stops it too, even
  # when held work already makes the step a decision.
  def test_a_link_into_a_sibling_worktree_goes_to_a_person
    root, feature = owned_worktree
    sibling = File.join(@directory, 'sibling')
    git('-C', root, 'worktree', 'add', '-q', sibling)
    link = File.join(@home, '.agents/skills/shaka')
    File.unlink(link)
    File.symlink(File.join(sibling, 'skills/shaka'), link)
    File.write(File.join(feature, 'notes.txt'), 'draft')
    output = refusal(feature, '--directory', feature)
    assert_includes output, 'Next: a person must decide where the skills links'
    assert_path_exists sibling
  end

  def test_an_owned_worktree_holding_work_goes_to_a_person
    _root, feature = owned_worktree
    File.write(File.join(feature, 'notes.txt'), 'draft')
    output = refusal(feature, '--directory', feature)
    assert_includes output,
                    "Next: a person must decide whether to keep the uncommitted files in #{File.realpath(feature)}"
  end

  # Another account could replace an unsafe owner's installer, so status runs from the worktree instead.
  def test_an_unsafe_owner_never_names_its_own_installer
    root, feature = owned_worktree
    File.chmod(0o775, root)
    output = refusal(feature, '--directory', feature)
    refute_includes output, File.join(File.realpath(root), 'bin/install')
    assert_includes output, "#{feature}/bin/install --status"
  ensure
    File.chmod(0o755, root) if root
  end

  # Only the default location refuses a reinstall over its own worktree; any other owner keeps that step.
  def test_a_custom_owner_keeps_the_reinstall_step
    root = clone_to(File.join(@directory, 'custom'))
    run_install(root, '--directory', root, '--repository', @remote)
    feature = File.join(@directory, 'feature')
    git('-C', root, 'worktree', 'add', '-q', feature)
    assert_includes refusal(feature, '--directory', feature), 'Install from a separate clone. Next: '
  end

  # A host skills folder that is itself a link into the worktree would go with it.
  def test_a_skills_folder_linked_into_the_worktree_goes_to_a_person
    _root, feature = owned_worktree
    custom = File.join(@directory, 'linked-skills')
    File.symlink(File.join(feature, 'skills'), custom)
    output = refusal(feature, '--directory', feature, '--skills-dir', custom)
    assert_includes output, "Next: a person must decide where the skills links #{custom}/shaka"
  end

  private

  # A default install hosting a linked worktree on a new branch.
  def owned_worktree
    root = default_install
    feature = File.join(@directory, 'feature')
    git('-C', root, 'worktree', 'add', '-q', feature)
    [root, feature]
  end
end
