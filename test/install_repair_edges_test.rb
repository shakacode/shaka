# frozen_string_literal: true

require_relative 'install_repair_support'

# Repair at the edges of what it may change: a link the user chose, and a step that must run again.
class InstallRepairEdgesTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRepairSupport

  def setup
    super
    git('-C', @remote, 'symbolic-ref', 'HEAD', 'refs/heads/main')
  end

  # A live checkout the user linked on purpose is theirs to decide about.
  def test_a_link_to_another_checkout_is_left_alone
    root = local_install
    File.unlink(host_link)
    File.symlink(File.join(@root, 'skills/shaka'), host_link)
    before = snapshot
    output, process = repair(root)
    refute_predicate process, :success?
    refute_includes output, 'Repairing'
    assert_equal before, snapshot
  end

  # A kept branch from an earlier attempt does not stop the step from running again.
  def test_local_commits_repair_again_after_a_kept_branch_exists
    root = local_install
    commit(root, 'local change')
    git('-C', root, 'branch', "kept-#{git('-C', root, 'rev-parse', '--short', 'HEAD').strip}")
    assert_repaired(root, 'B2', final: 'C3')
  end

  # A GIT_DIR left in the environment must not point the step's Git commands at another repository.
  def test_local_commits_repair_ignores_an_inherited_git_dir
    root = local_install
    commit(root, 'local change')
    other = git('-C', @root, 'rev-parse', 'HEAD').strip
    output, process = repair(root, 'GIT_DIR' => File.join(@root, '.git'))
    assert_includes output, 'Repairing B2', output
    refute_predicate process, :success?
    assert_equal other, git('-C', @root, 'rev-parse', 'HEAD').strip
    assert_equal 'C3', status(root)['state']
  end

  # A link into another registered checkout whose skill is missing belongs to that checkout.
  def test_a_missing_skill_in_another_checkout_is_not_relinked
    root = local_install('--agent', 'codex', '--agent', 'cursor')
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'claude')
    File.unlink(host_link)
    File.symlink(File.join(@root, 'skills/missing'), host_link)
    finding = status(root)['findings'].find { |item| item['location'] == host_link }
    assert_equal 'B9', finding['id']
    assert_nil finding['next_command']
  end
end
