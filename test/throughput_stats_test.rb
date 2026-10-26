# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/pr_watch'

# Spend and build latency stay in one marked block, and unknown times are never zero.
# rubocop:disable-next Metrics/ClassLength
class ThroughputStatsTest < Minitest::Test
  HEAD = 'a' * 40
  NEXT = 'b' * 40
  LATER = Time.utc(2026, 10, 26, 20, 0, 0)
  START = Time.utc(2026, 10, 26, 18, 0, 0)
  PUSH = Time.utc(2026, 10, 26, 18, 38, 0)
  READY = Time.utc(2026, 10, 26, 19, 19, 0)
  MERGED = Time.utc(2026, 10, 26, 21, 24, 0)

  def test_the_stats_line_leads_with_spend_and_pending_placeholders
    rendered = describe
    assert_match(/\A🤖 Codex · OpenAI · gpt-5\.6-terra · low\n\n<!-- shaka:stats \{/, rendered)
    assert_includes rendered, 'AI spend UNKNOWN · Prompt to CI UNKNOWN · CI to ready pending · Ready to merged pending'
    assert_operator rendered.index('AI spend'), :<, rendered.index('## Summary')
    refute_includes rendered, 'AI spend $0'
    refute_includes rendered, 'Usage and cost ·'
  end

  def test_a_known_zero_stays_distinct_from_unknown
    assert_includes describe('$0.00'), 'AI spend $0.00'
  end

  def test_prompt_to_ci_uses_task_start_and_the_head_push
    rendered = describe('$4.12', timeline: { 'task_started_at' => START, 'head_pushed_at' => PUSH })
    assert_includes rendered, 'AI spend $4.12 · Prompt to CI 38m · CI to ready pending · Ready to merged pending'
    assert_includes rendered, '| openai | $4.12 |'
  end

  def test_a_sub_minute_interval_is_not_zero_and_a_reversed_clock_is_unknown
    short = { 'task_started_at' => START, 'head_pushed_at' => START + 30 }
    assert_includes describe('UNKNOWN', timeline: short), 'Prompt to CI <1m'
    reversed = { 'task_started_at' => PUSH, 'head_pushed_at' => START }
    assert_includes describe('UNKNOWN', timeline: reversed), 'Prompt to CI UNKNOWN'
  end

  def test_the_publisher_note_stays_under_the_stats_line
    noted = content.merge('publisher_note' => 'Served model unavailable.')
    rendered = Shaka::Publication.description(noted)
    assert_operator rendered.index('AI spend'), :<, rendered.index('_Served model unavailable._')
  end

  def test_updating_the_block_is_idempotent_and_leaves_the_rest_of_the_body
    body = "Keep this.\n\n#{describe}\nAnd this.\n"
    changes = { 't2' => READY.iso8601, 'rounds' => 2, 'first_push' => START.iso8601, 'head' => HEAD }
    updated = Shaka::ThroughputStats.update(body, changes)
    assert_equal updated, Shaka::ThroughputStats.update(updated, changes)
    assert updated.start_with?("Keep this.\n\n")
    assert updated.end_with?("\nAnd this.\n")
    assert_includes updated, 'CI to ready 1h 19m (2 rounds)'
    assert_includes updated, 'Prompt to CI UNKNOWN'
    assert_equal 1, updated.scan('<!-- shaka:stats ').size
  end

  def test_a_second_block_or_a_zero_round_count_is_refused
    body = "#{describe}\n#{describe}"
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(body, 'spend' => '$1.00') }
    one = describe
    error = assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(one, 'rounds' => 0) }
    assert_includes error.message, 'positive'
    assert_equal 'no block here', Shaka::ThroughputStats.update('no block here', 'spend' => '$1.00')
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(one, 'spend' => 'x-->y') }
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(one, 'spend' => 'x--!>y') }
  end

  def test_republishing_keeps_ready_time_for_the_same_head
    again = republish(MERGED, HEAD, PUSH)
    assert_includes again, 'CI to ready 41m (1 round)'
    assert_includes again, 'Ready to merged 2h 5m'
  end

  def test_republishing_clears_ready_time_for_a_new_head
    moved = republish(nil, NEXT, READY)
    assert_includes moved, 'CI to ready pending'
    assert_includes moved, 'Prompt to CI 1h 19m'
  end

  def test_ready_to_merged_without_a_ready_time_is_unknown
    timeline = { 'task_started_at' => START, 'head_pushed_at' => PUSH, 'merged' => MERGED }
    assert_includes describe('UNKNOWN', timeline:), 'Ready to merged UNKNOWN'
  end

  def test_round_count_grows_only_after_a_failed_head
    assert_nil Shaka::ThroughputStats.rounds([])
    assert_equal 1, Shaka::ThroughputStats.rounds([{ 'failed' => false }])
    assert_equal 1, Shaka::ThroughputStats.rounds([{ 'failed' => false }, { 'failed' => false }])
    assert_equal 2, Shaka::ThroughputStats.rounds([{ 'failed' => true }, { 'failed' => false }])
    assert_equal 3, Shaka::ThroughputStats.rounds([{ 'failed' => true }, { 'failed' => true }, { 'failed' => false }])
    # A cancelled head is not a failure, so the push after it does not add another round.
    cancelled = [{ 'failed' => true }, { 'failed' => false }, { 'failed' => false }]
    assert_equal 2, Shaka::ThroughputStats.rounds(cancelled)
  end

  def test_ci_heads_count_a_failure_then_a_fix
    heads, complete = Shaka::ThroughputStats.ci_heads(commit_runs, required: ['validate'], review_jobs: [])
    assert complete
    assert_equal 2, Shaka::ThroughputStats.rounds(heads)
    assert_equal START.iso8601, Shaka::ThroughputStats.first_push(heads)
  end

  def test_ci_heads_notice_a_cut_off_history
    cut = { 'oid' => HEAD, 'checkSuites' => { 'pageInfo' => { 'hasNextPage' => true }, 'nodes' => [
      { 'checkRuns' => { 'nodes' => [check_run('validate', 'FAILURE')] } }
    ] } }
    _heads, seen = Shaka::ThroughputStats.ci_heads([cut], required: ['validate'], review_jobs: [])
    refute seen
  end

  def test_ready_time_is_the_last_green_check_the_wait_requires
    rows = [check('validate', '2026-10-26T19:00:00Z'), check('claude-review', '2026-10-26T19:19:00Z'),
            check('codex-review', '2026-10-26T19:40:00Z', 'fail')]
    ready = Shaka::ThroughputStats.ready_at(rows, required: ['validate'], review_jobs: %w[claude-review codex-review],
                                                  wait: 'one')
    assert_equal Time.utc(2026, 10, 26, 19, 19), ready
    assert_nil Shaka::ThroughputStats.ready_at(rows, required: ['validate'],
                                                     review_jobs: %w[claude-review codex-review], wait: 'all')
    undated = [check('validate', nil)]
    assert_equal :unknown, Shaka::ThroughputStats.ready_at(undated, required: ['validate'], review_jobs: [],
                                                                    wait: 'none')
  end

  def test_a_complete_page_keeps_the_earlier_of_the_carried_and_seen_push
    later = [{ 'pushed_at' => LATER.iso8601 }]
    assert_equal PUSH.iso8601, Shaka::ThroughputStats.bounded_first_push(later, true, { 'first_push' => PUSH.iso8601 })
    earlier = [{ 'pushed_at' => PUSH.iso8601 }]
    assert_equal PUSH.iso8601,
                 Shaka::ThroughputStats.bounded_first_push(earlier, true, { 'first_push' => LATER.iso8601 })
  end

  def test_an_unfinished_review_does_not_hide_a_failed_check
    runs = [check_run('validate', 'FAILURE'), { 'name' => 'claude-review', 'status' => 'IN_PROGRESS' }]
    head = { 'oid' => HEAD, 'pushedDate' => PUSH.iso8601, 'runs' => runs }
    found = Shaka::ThroughputStats.ci_heads([head], required: ['validate'], review_jobs: ['claude-review'])
    assert found[0].dig(0, 'failed')
  end

  def test_a_commit_status_failure_counts_as_a_round
    status = { 'oid' => '1' * 40, 'pushedDate' => START.iso8601, 'status' => { 'contexts' => [
      { 'context' => 'validate', 'state' => 'FAILURE', 'createdAt' => START.iso8601 }
    ] } }
    fixed = { 'oid' => HEAD, 'pushedDate' => PUSH.iso8601, 'runs' => [check_run('validate', 'SUCCESS')] }
    heads, complete = Shaka::ThroughputStats.ci_heads([status, fixed], required: ['validate'], review_jobs: [])
    assert complete
    assert_equal 2, Shaka::ThroughputStats.rounds(heads)
    assert_equal START.iso8601, Shaka::ThroughputStats.first_push(heads)
  end

  def test_a_cut_off_history_keeps_an_earlier_first_push_and_does_not_invent_one
    kept = watch_cut_off(filled_block)
    assert_includes kept, "\"first_push\":\"#{PUSH.iso8601}\""
    refute_includes kept, LATER.iso8601
    assert_includes kept, 'UNKNOWN rounds'

    invented = watch_cut_off(Shaka::ThroughputStats.update(filled_block, 'first_push' => nil))
    assert_includes invented, '"first_push":"UNKNOWN"'
    refute_includes invented, LATER.iso8601
  end

  def test_pr_watch_fills_the_block_once_from_github_timestamps
    github = watch_github
    publisher = Shaka::PrWatch::ThroughputPublisher.new(github, head: HEAD,
                                                                review_jobs: ['claude-review'], wait: 'one')
    2.times { publisher.call(required: ['validate']) }
    assert_equal 1, github.patches.size
    assert_throughput_patch(github.patches.first)
  end

  private

  def republish(merged, sha, pushed)
    filled = filled_block
    times = { 'task_started_at' => START, 'head_pushed_at' => pushed }
    times['merged'] = merged if merged
    describe('$4.12', timeline: times, pull: { 'head' => { 'sha' => sha }, 'body' => filled })
  end

  def filled_block
    first = describe('$4.12', timeline: { 'task_started_at' => START, 'head_pushed_at' => PUSH },
                              pull: { 'head' => { 'sha' => HEAD } })
    Shaka::ThroughputStats.update(first, 't2' => READY.iso8601, 'rounds' => 1,
                                         'first_push' => PUSH.iso8601, 'head' => HEAD)
  end

  def commit_runs
    [{ 'oid' => '1' * 40, 'pushedDate' => START.iso8601, 'runs' => [check_run('validate', 'FAILURE')] },
     { 'oid' => HEAD, 'pushedDate' => PUSH.iso8601, 'runs' => [check_run('validate', 'SUCCESS')] }]
  end

  def watch_cut_off(block)
    page = { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 60, 'nodes' => [
      { 'commit' => { 'oid' => HEAD, 'pushedDate' => LATER.iso8601,
                      'runs' => [check_run('validate', 'SUCCESS')] } }
    ] } }
    github = FakeGitHub.new("Intro.\n\n#{block}\n", page, [check('validate', READY.iso8601)])
    Shaka::PrWatch::ThroughputPublisher.new(github, head: HEAD, review_jobs: [], wait: 'none')
                                       .call(required: ['validate'])
    github.patches.fetch(0)
  end

  def watch_github
    body = "Intro.\n\n#{describe('$4.12', timeline: push_times, pull: { 'head' => { 'sha' => HEAD } })}\n\nOutro.\n"
    FakeGitHub.new(body, history, [check('validate', READY.iso8601), check('claude-review', READY.iso8601)])
  end

  def push_times = { 'task_started_at' => START, 'head_pushed_at' => PUSH }

  def assert_throughput_patch(patched)
    assert patched.start_with?("Intro.\n\n")
    assert patched.end_with?("\n\nOutro.\n")
    assert_includes patched, 'CI to ready 1h 19m (2 rounds)'
    assert_includes patched, 'AI spend $4.12'
    assert_includes patched, 'Prompt to CI 38m'
  end

  def describe(usd = 'UNKNOWN', timeline: nil, pull: nil)
    full = timeline && { 'opened' => START, 'labels' => [] }.merge(timeline)
    Shaka::Publication.description(content(usd), nil, pull, nil, full)
  end

  def content(usd = 'UNKNOWN')
    column = PublicationRegressionTest::USAGE_COLUMN.merge('usd' => usd)
    { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'Review the change.',
      'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'intent' => INTENT, 'verification' => VERIFICATION,
      'deployment' => 'none', 'steps_besides_merging' => 'none', 'provenance' => PUBLIC_PROVENANCE,
      'usage' => { 'note' => 'Native usage is PARTIAL.', 'records' => [USAGE_RECORD.merge('columns' => [column])] },
      'details' => [] }
  end

  def check_run(name, conclusion) = { 'name' => name, 'status' => 'COMPLETED', 'conclusion' => conclusion }

  def check(name, completed_at, bucket = 'pass')
    { 'name' => name, 'bucket' => bucket, 'completedAt' => completed_at }
  end

  def history
    failed = { 'oid' => '1' * 40, 'pushedDate' => START.iso8601, 'runs' => [check_run('validate', 'FAILURE')] }
    fixed = { 'oid' => HEAD, 'pushedDate' => PUSH.iso8601, 'runs' => [check_run('validate', 'SUCCESS')] }
    { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 2, 'nodes' => [
      { 'commit' => failed }, { 'commit' => fixed }
    ] } }
  end

  # Serves one pull's body, commit history, and current check timestamps.
  class FakeGitHub
    attr_reader :patches

    def initialize(body, pull, checks)
      @body = body
      @pull = pull
      @checks = checks
      @patches = []
    end

    def repository = 'owner/repo'
    def number = 7
    def graphql(*) = { 'repository' => { 'pullRequest' => @pull } }
    def check_times = @checks

    def api(_path, method: 'GET', fields: {}, expected: Hash, headers: []) # rubocop:disable Lint/UnusedMethodArgument
      return { 'body' => @body } unless method == 'PATCH'

      @patches << fields.fetch(:body)
      @body = fields.fetch(:body)
      { 'body' => @body }
    end
  end
end
