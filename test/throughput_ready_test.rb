# frozen_string_literal: true

require_relative 'throughput_helper'

# The ready time is when the current head's required checks and configured reviews last turned green.
class ThroughputReadyTest < Minitest::Test
  include ThroughputHelper

  def test_ready_time_waits_for_every_required_review
    rows = [check('validate', '2026-10-26T19:00:00Z'), check('claude-review', '2026-10-26T19:19:00Z'),
            check('codex-review', '2026-10-26T19:40:00Z', 'fail')]
    jobs = %w[claude-review codex-review]
    assert_equal Time.utc(2026, 10, 26, 19, 19), at(rows, jobs, 'one')
    assert_nil at(rows, jobs, 'all')
    assert_equal :unknown, at([check('validate', nil)], [], 'none')
    assert_equal :unknown, at([check('validate', '0001-01-01T00:00:00Z')], [], 'none')
  end

  def test_a_skipped_review_does_not_mark_the_ready_time
    rows = [check('validate', '2026-10-26T19:00:00Z'), check('claude-review', '2026-10-26T19:05:00Z', 'skipping'),
            check('codex-review', '2026-10-26T19:40:00Z')]
    assert_equal Time.utc(2026, 10, 26, 19, 40), at(rows, %w[claude-review codex-review], 'one')
  end

  def test_a_skipped_required_check_is_ready
    skipped = check('validate', READY.iso8601, 'skipping').merge('state' => 'SKIPPED')
    assert_equal READY, at([skipped], [], 'none')
  end

  def test_the_check_start_ignores_a_placeholder_suite_time
    commit = gql(HEAD, PUSH.iso8601, [check_run('validate', 'SUCCESS').merge('startedAt' => LATER.iso8601)])
    commit['checkSuites']['nodes'] << { 'createdAt' => '0001-01-01T00:00:00Z', 'checkRuns' => { 'nodes' => [] } }
    assert_equal PUSH.iso8601, Shaka::ThroughputStats.prompt_stamp(commit)
  end

  def test_an_earlier_commit_status_starts_ci
    commit = gql(HEAD, PUSH.iso8601, []).merge('status' => { 'contexts' => [{ 'createdAt' => START.iso8601 }] })
    assert_equal START.iso8601, Shaka::ThroughputStats.prompt_stamp(commit)
  end

  def test_republishing_the_same_head_keeps_the_earlier_check_start
    later = { 'task_started_at' => START, 'ci_started_at' => PUSH + 300 }
    rendered = describe('$4.12', timeline: later, pull: { 'head' => { 'sha' => HEAD }, 'body' => filled_block })
    assert_includes rendered, 'Prompt to CI 38m'
  end

  def test_an_update_after_the_gate_turned_green_shows_the_time_to_ready
    rendered = describe('$4.12', timeline: push_times.merge('ready_at' => READY), pull: head_pull)
    assert_includes rendered, '· ready in 1h 19m'
    assert_includes rendered, 'CI to ready 41m'
  end

  def test_republishing_the_same_head_keeps_the_earlier_ready_time
    later = push_times.merge('ready_at' => LATER)
    rendered = describe('$4.12', timeline: later, pull: head_pull.merge('body' => filled_block))
    assert_includes rendered, '· ready in 1h 19m'
  end

  def test_a_ready_time_replaces_one_no_timestamps_could_establish
    body = Shaka::ThroughputStats.update(filled_block, 't2' => 'UNKNOWN')
    rendered = describe('$4.12', timeline: push_times.merge('ready_at' => READY), pull: head_pull.merge('body' => body))
    assert_includes rendered, '· ready in 1h 19m'
  end

  def test_a_new_head_does_not_keep_the_old_heads_ready_time
    pull = { 'head' => { 'sha' => NEXT }, 'body' => filled_block }
    assert_includes describe('$4.12', timeline: push_times, pull:), 'CI to ready pending'
    assert_includes describe('$4.12', timeline: push_times.merge('ready_at' => LATER), pull:), '· ready in 2h 0m'
  end

  private

  def at(rows, jobs, wait) = Shaka::ThroughputStats.ready_at(rows, required: ['validate'], review_jobs: jobs, wait:)
end
