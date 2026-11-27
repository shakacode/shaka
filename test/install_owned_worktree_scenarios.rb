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

  # Git reads an unsafe owner's config, which can name commands, so the step repairs its modes and nothing runs.
  def test_an_unsafe_owner_gets_its_mode_repair_and_no_git_read
    root, feature = owned_worktree
    git('-C', root, 'config', 'core.fsmonitor', "touch #{File.join(@directory, 'ran')}")
    File.chmod(0o775, root)
    output = refusal(feature, '--directory', feature)
    refute_includes output, File.join(File.realpath(root), 'bin/install')
    assert_match(/Next: chmod /, output)
    refute_path_exists File.join(@directory, 'ran')
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
