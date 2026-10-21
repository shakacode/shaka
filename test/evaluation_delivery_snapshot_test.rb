# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_snapshot'
require_relative 'support/evaluation_snapshot_fixture'

class EvaluationDeliverySnapshotTest < Minitest::Test
  include EvaluationSnapshotFixture

  def test_native_app_run_head_and_final_blob_bounds_are_retained
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = capture
    assert_equal({ 'lib/a space.rb' => 3 }, result['changed_files'])
    assert_equal 'c' * 40, result.dig('blobs', 'lib/a space.rb', 'oid')
    assert_equal({ 'id' => 118_040_128_127, 'app_id' => 15_368, 'suite_id' => 7 },
                 result['checks'][0].slice('id', 'app_id', 'suite_id'))
    assert_operator result.dig('checks', 0, 'observed_at'), :>, before
    assert_operator result['observed_at'], :>, result.dig('checks', 0, 'observed_at')
  end

  def test_requests_are_read_only_and_blob_expressions_pin_the_full_head
    capture
    rows = requests
    assert_equal ['api', '--hostname', 'github.com', '--method', 'GET',
                  "repos/fixture-org/cell/commits/#{HEAD}/check-runs?per_page=100&filter=latest&app_id=15368"],
                 rows[1]['argv']
    query = JSON.parse(rows[2]['input'])
    assert_equal "#{HEAD}:lib/a space.rb", query.dig('variables', 'p0')
    refute_includes query.fetch('query'), 'lib/a space.rb'
  end

  def test_graphql_requests_never_mutate
    capture
    assert(requests.values_at(0, 2, 3).all? { JSON.parse(it['input']).fetch('query').start_with?('query') })
  end

  def test_wrong_app_head_or_run_identity_cannot_be_normalized
    [{ 'id' => 0 }, { 'head_sha' => 'd' * 40 }, { 'app' => { 'id' => 9 } },
     { 'check_suite' => nil }].each do |change|
      rows = checks
      rows['check_runs'][0].merge!(change)
      assert_raises(IOError) { capture([pull, rows, blobs, pull]) }
    end
  end

  def test_missing_and_pending_checks_are_observations_without_a_success_claim
    result = capture([pull, { 'total_count' => 0, 'check_runs' => [] }, blobs, pull])
    assert_empty result['checks']
    rows = checks
    rows['check_runs'][0].merge!('status' => 'in_progress', 'conclusion' => nil)
    assert_nil capture([pull, rows, blobs, pull]).dig('checks', 0, 'conclusion')
  end

  def test_duplicate_or_incomplete_native_lists_are_unavailable
    duplicate = checks
    duplicate['check_runs'] *= 2
    duplicate['total_count'] = 2
    [duplicate, checks.merge('total_count' => 101), checks.merge('total_count' => 0)].each do |rows|
      assert_raises(IOError) { capture([pull, rows, blobs, pull]) }
    end
  end

  def test_incomplete_file_list_is_unavailable
    row = pull
    row.dig('data', 'repository', 'pullRequest', 'files', 'pageInfo')['hasNextPage'] = true
    assert_raises(IOError) { capture([row]) }
  end

  def test_head_base_or_file_set_movement_during_collection_is_unavailable
    %w[headRefOid baseRefOid changedFiles].each do |field|
      row = pull
      row.dig('data', 'repository', 'pullRequest')[field] = field == 'changedFiles' ? 2 : 'd' * 40
      assert_raises(IOError) { capture([pull, checks, blobs, row]) }
    end
  end

  def test_final_merge_is_retained_for_the_ask_grader_to_reject
    row = pull
    row.dig('data', 'repository', 'pullRequest').merge!('state' => 'MERGED', 'merged' => true,
                                                        'mergeCommit' => { 'oid' => 'd' * 40 })
    result = capture([pull, checks, blobs, row])
    assert result.dig('pull', 'merged')
    assert_equal 'MERGED', result.dig('pull', 'state')
  end

  def test_binary_blobs_never_supply_line_bounds
    rows = blobs
    rows.dig('data', 'repository', 'b0').merge!('isBinary' => true, 'text' => nil)
    assert_empty capture([pull, checks, rows, pull])['changed_files']
  end

  def test_deleted_files_need_no_final_blob
    row = pull
    row.dig('data', 'repository', 'pullRequest', 'files', 'nodes')[0]['changeType'] = 'DELETED'
    result = capture([row, checks, row])
    assert_empty result['changed_files']
    assert_empty result['blobs']
  end
end
