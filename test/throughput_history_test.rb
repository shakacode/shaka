# frozen_string_literal: true

require_relative 'throughput_helper'

# CI history counts failed rounds and keeps the earliest real push and ready time.
class ThroughputHistoryTest < Minitest::Test
  include ThroughputHelper

  def test_round_count_grows_only_after_a_failed_head
    counted = round_cases.map { |heads| Shaka::ThroughputStats.rounds(heads) }
    assert_equal [nil, 1, 1, 2, 3, 2], counted
  end

  def test_ci_history_counts_check_run_and_commit_status_failures
    heads, complete = heads_of(commit_runs)
    assert complete
    assert_equal [2, START.iso8601], [Shaka::ThroughputStats.rounds(heads), Shaka::ThroughputStats.first_push(heads)]
    counted, seen = heads_of(status_then_fix)
    assert seen
    assert_equal [2, START.iso8601], [Shaka::ThroughputStats.rounds(counted), counted.dig(0, 'pushed_at')]
  end

  def test_a_cut_off_check_history_is_incomplete
    cut = { 'oid' => HEAD, 'checkSuites' => { 'pageInfo' => { 'hasNextPage' => true }, 'nodes' => [
      { 'checkRuns' => { 'nodes' => [check_run('validate', 'FAILURE')] } }
    ] } }
    refute heads_of([cut]).last
  end

  def test_a_completed_failure_counts_while_a_sibling_check_runs
    runs = [check_run('validate', 'FAILURE'), { 'name' => 'claude-review', 'status' => 'IN_PROGRESS' }]
    found = Shaka::ThroughputStats.ci_heads([gql(HEAD, PUSH.iso8601, runs)], required: ['validate'],
                                                                             review_jobs: ['claude-review'])
    assert found[0].dig(0, 'failed')
  end

  def test_the_first_push_ignores_a_placeholder_suite_time
    assert_equal PUSH.iso8601, heads_of([started_commit]).first.dig(0, 'pushed_at')
  end

  def test_ready_time_waits_for_every_required_review
    rows = [check('validate', '2026-10-26T19:00:00Z'), check('claude-review', '2026-10-26T19:19:00Z'),
            check('codex-review', '2026-10-26T19:40:00Z', 'fail')]
    jobs = %w[claude-review codex-review]
    assert_equal Time.utc(2026, 10, 26, 19, 19), at(rows, jobs, 'one')
    assert_nil at(rows, jobs, 'all')
    assert_equal :unknown, at([check('validate', nil)], [], 'none')
  end

  def test_a_skipped_review_does_not_mark_the_ready_time
    rows = [check('validate', '2026-10-26T19:00:00Z'), check('claude-review', '2026-10-26T19:05:00Z', 'skipping'),
            check('codex-review', '2026-10-26T19:40:00Z')]
    assert_equal Time.utc(2026, 10, 26, 19, 40), at(rows, %w[claude-review codex-review], 'one')
  end

  def test_a_skipped_required_check_is_ready_and_the_earlier_push_is_kept
    skipped = check('validate', READY.iso8601, 'skipping').merge('state' => 'SKIPPED')
    assert_equal READY, at([skipped], [], 'none')
    later = [{ 'pushed_at' => LATER.iso8601 }]
    assert_equal PUSH.iso8601, bounded(later, PUSH.iso8601)
    earlier = [{ 'pushed_at' => PUSH.iso8601 }]
    assert_equal PUSH.iso8601, bounded(earlier, LATER.iso8601)
  end

  private

  def at(rows, jobs, wait) = Shaka::ThroughputStats.ready_at(rows, required: ['validate'], review_jobs: jobs, wait:)
  def bounded(heads, kept) = Shaka::ThroughputStats.bounded_first_push(heads, true, { 'first_push' => kept })

  def round_cases
    ok = { 'failed' => false }
    bad = { 'failed' => true }
    [[], [ok], [ok, ok], [bad, ok], [bad, bad, ok], [bad, ok, ok]]
  end

  def status_then_fix
    status = { 'oid' => '1' * 40, 'status' => { 'contexts' => [
      { 'context' => 'validate', 'state' => 'FAILURE', 'createdAt' => START.iso8601 }
    ] } }
    [status, gql(HEAD, PUSH.iso8601, [check_run('validate', 'SUCCESS')])]
  end

  def started_commit
    commit = gql(HEAD, nil, [check_run('validate', 'SUCCESS').merge('startedAt' => LATER.iso8601)])
    commit['checkSuites']['nodes'][0]['createdAt'] = PUSH.iso8601
    commit['checkSuites']['nodes'] << { 'createdAt' => '0001-01-01T00:00:00Z', 'checkRuns' => { 'nodes' => [] } }
    commit
  end
end
