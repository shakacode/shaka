# frozen_string_literal: true

require_relative 'install_repair_support'

# `install --repair` runs the steps status names for the states it may change. Each test builds a state
# from a local remote, repairs it, checks the result, and repairs again to prove nothing changes.
class InstallRepairTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRepairSupport

  def setup
    super
    git('-C', @remote, 'symbolic-ref', 'HEAD', 'refs/heads/main')
  end

  def test_a_pull_is_recorded
    root = local_install.tap { |checkout| pull(checkout) }
    assert_repaired(root, 'B1')
  end

  def test_a_pending_update_finishes
    root = local_install
    head = git('-C', root, 'rev-parse', 'HEAD').strip
    record = File.join(root, '.git/shaka-install.json')
    File.write(record, JSON.generate(JSON.parse(File.read(record)).merge('pending_revision' => head)))
    assert_repaired(root, 'B7')
  end

  def test_a_removed_ruby_is_recorded_again
    root = local_install
    File.write(File.join(root, '.git/shaka-ruby'), "/nonexistent/ruby\n")
    assert_repaired(root, 'B8')
  end

  def test_a_missing_link_comes_back
    root = local_install
    File.unlink(host_link)
    assert_repaired(root, 'B9')
  end

  def test_a_link_to_nothing_points_at_its_owner_again
    root = local_install
    File.unlink(host_link)
    File.symlink(File.join(@directory, 'gone/skills/shaka'), host_link)
    assert_repaired(root, 'B9')
  end

  def test_an_orphan_record_is_renamed_aside
    orphan = local_install
    File.unlink(host_link)
    run_install(@root, '--directory', @root, '--repository', @remote)
    assert_repaired(@root, 'C1', retired: [orphan])
  end

  # The commits stay on a kept branch, which status then names as development in the checkout.
  def test_local_commits_move_to_a_branch
    root = local_install
    commit(root, 'local change')
    head = git('-C', root, 'rev-parse', 'HEAD').strip
    short = git('-C', root, 'rev-parse', '--short', 'HEAD').strip
    assert_repaired(root, 'B2', final: 'C3')
    assert_equal head, git('-C', root, 'rev-parse', "kept-#{short}").strip
  end

  # The checkout with the newer record keeps both hosts; the other record is retired.
  def test_a_split_install_unifies_under_the_newer_record
    older = local_install('--agent', 'claude')
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'cursor')
    assert_repaired(@root, 'C5', retired: [older])
    %w[.claude .cursor].each do |host|
      assert_equal File.join(File.realpath(@root), 'skills/shaka'),
                   File.realpath(File.join(@home, host, 'skills/shaka'))
    end
  end

  # Status names the split with both owners; neither record is changed.
  def test_two_records_claiming_one_host_are_refused_with_both_named
    older = local_install('--agent', 'claude')
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'cursor')
    claim_host(older, File.join(@home, '.cursor/skills'))
    before = snapshot
    output, process = repair(@root)
    refute_predicate process, :success?
    [older, @root].each { |root| assert_includes output, File.realpath(root) }
    assert_equal before, snapshot
  end

  def test_repair_takes_no_other_action_or_json
    [%w[--repair --json], %w[--repair --update], %w[--repair --agent claude]].each do |flags|
      output, process = Open3.capture2e(environment, RbConfig.ruby, File.join(@root, 'bin/install'), *flags)
      refute_predicate process, :success?, flags.inspect
      refute_includes output, 'Repairing', flags.inspect
    end
  end

  private

  def local_install(*)
    root = clone_to(default_path)
    run_install(root, '--directory', root, '--repository', @remote, *)
    root
  end

  def host_link = File.join(@home, '.agents/skills/shaka')

  def claim_host(root, directory)
    path = File.join(root, '.git/shaka-install.json')
    record = JSON.parse(File.read(path))
    record['targets'] << { 'directory' => directory, 'names' => ['shaka'] }
    File.write(path, JSON.generate(record))
  end
end
