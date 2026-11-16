# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_snapshot'
require_relative 'support/evaluation_snapshot_fixture'

class EvaluationDeliverySnapshotFailuresTest < Minitest::Test
  include EvaluationSnapshotFixture

  def test_missing_binary_or_truncated_blobs_never_supply_line_bounds
    [nil, { '__typename' => 'Tree' }, blobs.dig('data', 'repository', 'b0').merge('isTruncated' => true),
     blobs.dig('data', 'repository', 'b0').merge('byteSize' => 6)].each do |blob|
      rows = { 'data' => { 'repository' => { 'b0' => blob } } }
      assert_raises(IOError) { capture([pull, checks, rows, pull]) }
    end
  end

  def test_wrong_repository_and_fork_cannot_supply_evidence
    row = pull
    row.dig('data', 'repository')['nameWithOwner'] = 'another/cell'
    assert_raises(IOError) { capture([row]) }
    row = pull
    row.dig('data', 'repository', 'pullRequest', 'headRepository')['nameWithOwner'] = 'another/cell'
    assert_raises(IOError) { capture([row]) }
  end

  def test_unknown_or_partial_graphql_results_are_unavailable
    [nil, {}, { 'data' => nil }, pull.merge('errors' => [{ 'message' => 'private-error' }])].each do |row|
      error = assert_raises(IOError) { capture([row]) }
      refute_includes error.message, 'private-error'
    end
  end

  def test_inconsistent_merge_state_is_unavailable
    row = pull
    row.dig('data', 'repository', 'pullRequest')['merged'] = true
    assert_raises(IOError) { capture([row]) }
  end

  def test_snapshot_deadline_reaps_the_active_native_child
    pids = spawned_by_open3 { assert_raises(IOError) { capture([pull, 'hang'], seconds: 2) } }
    refute_empty pids
    pids.each { |pid| assert_raises(Errno::ESRCH) { Process.kill(0, pid) } }
  end

  def test_invalid_declared_apps_are_refused_before_native_access
    bad = plan.merge('check_apps' => { 'validate' => '15368' })
    assert_raises(ArgumentError) { Shaka::Evaluation::DeliverySnapshot.new(bad, github: @gh) }
    refute_path_exists File.join(@directory, 'requests')
  end

  private

  # The pids Open3 spawns, so the test needs no report from a child the deadline may stop before it runs.
  # The reads share one deadline, so on a loaded machine it can stop the first child instead of the hanging one.
  def spawned_by_open3
    pids = []
    Open3.define_singleton_method(:spawn) { |*arguments| Process.spawn(*arguments).tap { pids << it } }
    yield
    pids
  ensure
    Open3.singleton_class.remove_method(:spawn)
  end
end
