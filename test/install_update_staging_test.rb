# frozen_string_literal: true

require_relative 'install_repair_support'

# install --update checks a new revision in a temporary worktree. When the update is killed, that worktree
# stays registered; status reports it as an interrupted update, and the next update or repair removes it.
class InstallUpdateStagingTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRepairSupport

  def test_status_names_the_update_and_the_update_clears_the_staging_worktree
    root = local_install
    staging = add_staging(root)
    report = status(root)
    refute_includes report['findings'].map { |item| item['id'] }, 'C3'
    assert_includes report['detail'], staging
    assert_includes report['next_command'], 'install --update'
    run_next(report, 'B7')
    assert_cleared(root, staging)
  end

  def test_a_staging_worktree_whose_folder_is_gone_is_cleared_too
    root = local_install
    FileUtils.rm_rf(add_staging(root))
    run_next(status(root), 'B7')
    assert_empty staging_worktrees(root)
  end

  def test_repair_clears_the_staging_worktree
    root = local_install
    add_staging(root)
    assert_repaired(root, 'B7')
    assert_empty staging_worktrees(root)
  end

  def test_verify_does_not_call_the_staging_worktree_development
    root = local_install
    add_staging(root)
    output, process = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), '--verify')
    assert_predicate process, :success?, output
    refute_includes output, 'Warning:'
  end

  # Only a detached worktree at the exact path the installer makes is its own; anything else is a person's.
  def test_a_persons_worktree_stays_development_and_survives_the_update
    root = local_install
    lookalikes = [File.join(@directory, 'shaka-update-notes/source'), staging_path('attached')]
    git('-C', root, 'worktree', 'add', '-q', '--detach', lookalikes[0])
    git('-C', root, 'worktree', 'add', '-q', '-b', 'topic', lookalikes[1])
    assert_equal 'C3', status(root)['state']
    run_install(root, '--update')
    assert_equal(lookalikes.map { File.realpath(it) }, linked_worktrees(root))
  end

  private

  # The folder Dir.mktmpdir('shaka-update') makes, holding the staged checkout.
  def staging_path(suffix = 'abc123') = File.join(@directory, "shaka-update20261105-4242-#{suffix}", 'source')

  def add_staging(root)
    path = staging_path
    git('-C', root, 'worktree', 'add', '-q', '--detach', path)
    File.realpath(path)
  end

  def assert_cleared(root, staging)
    assert_empty staging_worktrees(root)
    refute_path_exists staging
    assert_equal 'ok', status(root)['severity']
  end

  def linked_worktrees(root)
    git('-C', root, 'worktree', 'list', '--porcelain').scan(/^worktree (.+)$/).flatten.drop(1)
  end

  def staging_worktrees(root) = linked_worktrees(root).grep(/shaka-update/)
end
