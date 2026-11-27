# frozen_string_literal: true

require_relative 'install_scenario_support'

# A failed Git read in the development cleanup proves nothing, so status and both installer refusals report
# what Shaka could not verify and never offer the forced discard that held work gets.
class InstallDevelopmentReadsTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps

  # Git cannot read a worktree whose index is damaged. Before, a failed status read counted as uncommitted
  # files and the step offered to discard them with --force --force.
  def test_a_failed_worktree_read_is_not_held_work
    root, feature = damaged_worktree
    report = status(root)
    assert_nil report['next_command']
    assert_includes report['decision'], "could not verify whether #{File.realpath(feature)} has uncommitted files"
    [refusal(root), refusal(feature, '--directory', feature)].each do |output|
      assert_includes output, 'could not verify whether'
      refute_match(/branch -D|--force/, output)
    end
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

  # A default install hosting a linked worktree whose index Git cannot read.
  def damaged_worktree
    root = default_install
    feature = File.join(@directory, 'feature')
    git('-C', root, 'worktree', 'add', '-q', feature)
    File.write(File.join(root, '.git/worktrees/feature/index'), 'damaged')
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
end
