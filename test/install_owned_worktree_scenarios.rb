# frozen_string_literal: true

# Installing into a worktree of the default install hands a person the decision whenever the install's own
# step would lose work or could not be read safely, and leaves any other owner's reinstall step alone (#1284).
module OwnedWorktreeScenarios
  def test_an_owned_worktree_holding_work_goes_to_a_person
    _root, feature = owned_worktree
    File.write(File.join(feature, 'notes.txt'), 'draft')
    output = refusal(feature, '--directory', feature)
    assert_includes output,
                    "Next: a person must decide whether to keep the uncommitted files in #{File.realpath(feature)}"
  end

  # Another account could replace an unsafe owner's files, so no command is printed for it.
  def test_an_unsafe_owner_never_names_its_own_installer
    root, feature = owned_worktree
    File.chmod(0o775, root)
    output = refusal(feature, '--directory', feature)
    refute_includes output, File.join(File.realpath(root), 'bin/install')
    assert_includes output, "Next: a person must decide how to make #{File.realpath(root)} safe to read"
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

  def test_an_unreadable_record_names_the_reason
    root, feature = owned_worktree
    File.write(File.join(root, '.git/shaka-install.json'), '{')
    output = refusal(feature, '--directory', feature)
    assert_includes output, 'which cannot be read (Installation record is invalid), then run this command again'
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
