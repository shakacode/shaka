# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/pr_watch'

# Spend and build latency stay in one marked block, and unknown times are never zero.
# rubocop:disable-next Metrics/AbcSize, Metrics/ClassLength, Metrics/MethodLength
class ThroughputStatsTest < Minitest::Test
  HEAD = 'a' * 40
  NEXT = 'b' * 40
  LATER = Time.utc(2026, 10, 26, 20, 0, 0)
  START = Time.utc(2026, 10, 26, 18, 0, 0)
  PUSH = Time.utc(2026, 10, 26, 18, 38, 0)
  READY = Time.utc(2026, 10, 26, 19, 19, 0)
  MERGED = Time.utc(2026, 10, 26, 21, 24, 0)
  PENDING = 'AI spend UNKNOWN · Prompt to CI UNKNOWN · CI to ready pending · Ready to merged pending'

  def test_the_stats_line_leads_with_spend_and_pending_placeholders
    rendered = describe
    assert_match(/\A🤖 Codex · OpenAI · gpt-5\.6-terra · low\n\n<!-- shaka:stats \{/, rendered)
    assert_includes rendered, PENDING
    assert_operator rendered.index('AI spend'), :<, rendered.index('## Summary')
    refute_includes rendered, 'AI spend $0'
    refute_includes rendered, 'Usage and cost ·'
    assert_includes describe('$0.00'), 'AI spend $0.00'
  end

  def test_prompt_to_ci_uses_the_check_start_before_the_push_time
    pushed = { 'task_started_at' => START, 'head_pushed_at' => PUSH }
    started = { 'task_started_at' => START, 'ci_started_at' => PUSH }
    assert_includes describe('$4.12', timeline: pushed), 'AI spend $4.12 · Prompt to CI 38m'
    assert_includes describe('$4.12', timeline: pushed), '| openai | $4.12 |'
    assert_includes describe('UNKNOWN', timeline: started), 'Prompt to CI 38m'
    short = { 'task_started_at' => START, 'head_pushed_at' => START + 30 }
    assert_includes describe('UNKNOWN', timeline: short), 'Prompt to CI <1m'
    assert_includes describe('UNKNOWN', timeline: { 'task_started_at' => PUSH, 'head_pushed_at' => START }),
                    'Prompt to CI UNKNOWN'
  end

  def test_the_publisher_note_stays_under_the_stats_line
    noted = content.merge('publisher_note' => 'Served model unavailable.')
    rendered = Shaka::Publication.description(noted)
    assert_operator rendered.index('AI spend'), :<, rendered.index('_Served model unavailable._')
  end

  def test_updating_the_block_is_idempotent_and_leaves_the_surrounding_text
    body = "Keep this.\n\n#{describe}\nAnd this.\n"
    changes = { 't2' => READY.iso8601, 'rounds' => 2, 'first_push' => START.iso8601, 'head' => HEAD }
    updated = Shaka::ThroughputStats.update(body, changes)
    assert_equal updated, Shaka::ThroughputStats.update(updated, changes)
    assert updated.start_with?("Keep this.\n\n") && updated.end_with?("\nAnd this.\n")
    assert_includes updated, 'CI to ready 1h 19m (2 rounds)'
    assert_equal 1, updated.scan('<!-- shaka:stats ').size
  end

  def test_a_bad_block_is_refused_and_crlf_outside_the_block_stays
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update("#{describe}\n#{describe}", 'spend' => '$1.00') }
    error = assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(describe, 'rounds' => 0) }
    assert_includes error.message, 'positive'
    assert_equal 'no block here', Shaka::ThroughputStats.update('no block here', 'spend' => '$1.00')
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(describe, 'spend' => 'x-->y') }
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(describe, 'spend' => 'x--!>y') }
    crlf = "Keep.\r\n#{describe.gsub("\n", "\r\n")}"
    assert_equal crlf, Shaka::ThroughputStats.update(crlf, {})
    assert_equal "older\r\n", Shaka::ThroughputStats.update("older\r\n", 'spend' => '$1.00')
  end

  def test_republishing_keeps_ready_time_only_for_the_same_head
    assert_includes republish(MERGED, HEAD, PUSH), 'CI to ready 41m (1 round)'
    assert_includes republish(MERGED, HEAD, PUSH), 'Ready to merged 2h 5m'
    assert_includes republish(nil, NEXT, READY), 'CI to ready pending'
    assert_includes republish(nil, NEXT, READY), 'Prompt to CI 1h 19m'
    merged = { 'task_started_at' => START, 'head_pushed_at' => PUSH, 'merged' => MERGED }
    assert_includes describe('UNKNOWN', timeline: merged), 'Ready to merged UNKNOWN'
  end

  def test_round_count_grows_only_after_a_failed_head
    counted = round_cases.map { |heads| Shaka::ThroughputStats.rounds(heads) }
    assert_equal [nil, 1, 1, 2, 3, 2], counted
  end

  def test_ci_history_counts_failures_stops_when_cut_off_and_ignores_a_placeholder_time
    heads, complete = heads_of(commit_runs)
    assert complete
    assert_equal [2, START.iso8601], [Shaka::ThroughputStats.rounds(heads), Shaka::ThroughputStats.first_push(heads)]
    counted, seen = heads_of(status_then_fix)
    assert seen
    assert_equal [2, START.iso8601], [Shaka::ThroughputStats.rounds(counted), counted.dig(0, 'pushed_at')]
    cut = { 'oid' => HEAD, 'checkSuites' => { 'pageInfo' => { 'hasNextPage' => true }, 'nodes' => [
      { 'checkRuns' => { 'nodes' => [check_run('validate', 'FAILURE')] } }
    ] } }
    refute heads_of([cut]).last
    runs = [check_run('validate', 'FAILURE'), { 'name' => 'claude-review', 'status' => 'IN_PROGRESS' }]
    found = Shaka::ThroughputStats.ci_heads([gql(HEAD, PUSH.iso8601, runs)], required: ['validate'],
                                                                             review_jobs: ['claude-review'])
    assert found[0].dig(0, 'failed')
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

  def test_a_skipped_required_check_is_ready_and_the_earlier_push_is_kept
    skipped = check('validate', READY.iso8601, 'skipping').merge('state' => 'SKIPPED')
    assert_equal READY, at([skipped], [], 'none')
    later = [{ 'pushed_at' => LATER.iso8601 }]
    assert_equal PUSH.iso8601, bounded(later, PUSH.iso8601)
    earlier = [{ 'pushed_at' => PUSH.iso8601 }]
    assert_equal PUSH.iso8601, bounded(earlier, LATER.iso8601)
  end

  def test_pr_watch_fills_prompt_to_ci_and_keeps_the_earlier_ready_time
    github = watch_github
    2.times { publish(github, ['claude-review'], 'one') }
    assert_equal 1, github.patches.size
    patched = github.patches.first
    assert patched.start_with?("Intro.\n\n") && patched.end_with?("\n\nOutro.\n")
    assert_includes patched, 'CI to ready 1h 19m (2 rounds)'
    assert_includes patched, 'Prompt to CI 38m'
    kept = watch_cut_off(filled_block)
    assert_includes kept, "\"first_push\":\"#{PUSH.iso8601}\""
    refute_includes kept, LATER.iso8601
    assert_includes kept, 'UNKNOWN rounds'
    invented = watch_cut_off(Shaka::ThroughputStats.update(filled_block, 'first_push' => nil))
    assert_includes invented, '"first_push":"UNKNOWN"'
    prompted = FakeGitHub.new(prompt_body, one_commit(nil, PUSH.iso8601), [check('validate', READY.iso8601)])
    publish(prompted, [], 'none')
    assert_includes prompted.patches.fetch(0), 'Prompt to CI 38m'
    rerun = FakeGitHub.new("Intro.\n\n#{filled_block}\n", history, [check('validate', (READY + 3600).iso8601)])
    publish(rerun, [], 'none')
    text = rerun.patches.last || "Intro.\n\n#{filled_block}\n"
    assert_includes text, READY.iso8601
    refute_includes text, (READY + 3600).iso8601
    moved = watch_github
    moved.moved_pull = history.merge('headRefOid' => NEXT)
    publish(moved, [], 'none')
    assert_empty moved.patches
  end

  private

  def at(rows, jobs, wait) = Shaka::ThroughputStats.ready_at(rows, required: ['validate'], review_jobs: jobs, wait:)
  def heads_of(commits) = Shaka::ThroughputStats.ci_heads(commits, required: ['validate'], review_jobs: [])

  def publish(github, jobs, wait)
    Shaka::PrWatch::ThroughputPublisher.new(github, head: HEAD, review_jobs: jobs, wait:).call(required: ['validate'])
  end

  def republish(merged, sha, pushed)
    times = { 'task_started_at' => START, 'head_pushed_at' => pushed }
    times['merged'] = merged if merged
    describe('$4.12', timeline: times, pull: { 'head' => { 'sha' => sha }, 'body' => filled_block })
  end

  def filled_block
    first = describe('$4.12', timeline: push_times, pull: { 'head' => { 'sha' => HEAD } })
    Shaka::ThroughputStats.update(first, 't2' => READY.iso8601, 'rounds' => 1, 'first_push' => PUSH.iso8601,
                                         'head' => HEAD)
  end

  def round_cases
    ok = { 'failed' => false }
    bad = { 'failed' => true }
    [[], [ok], [ok, ok], [bad, ok], [bad, bad, ok], [bad, ok, ok]]
  end

  def commit_runs
    [gql('1' * 40, START.iso8601, [check_run('validate', 'FAILURE')]),
     gql(HEAD, PUSH.iso8601, [check_run('validate', 'SUCCESS')])]
  end

  def status_then_fix
    status = { 'oid' => '1' * 40, 'pushedDate' => START.iso8601, 'status' => { 'contexts' => [
      { 'context' => 'validate', 'state' => 'FAILURE', 'createdAt' => START.iso8601 }
    ] } }
    [status, gql(HEAD, PUSH.iso8601, [check_run('validate', 'SUCCESS')])]
  end

  def watch_cut_off(block)
    page = { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 60, 'nodes' => [
      { 'commit' => gql(HEAD, LATER.iso8601, [check_run('validate', 'SUCCESS')]) }
    ] } }
    github = FakeGitHub.new("Intro.\n\n#{block}\n", page, [check('validate', READY.iso8601)])
    publish(github, [], 'none')
    github.patches.fetch(0)
  end

  def watch_github
    body = "Intro.\n\n#{describe('$4.12', timeline: push_times, pull: { 'head' => { 'sha' => HEAD } })}\n\nOutro.\n"
    FakeGitHub.new(body, history, [check('validate', READY.iso8601), check('claude-review', READY.iso8601)])
  end

  def prompt_body = "Intro.\n\n#{describe('$4.12', timeline: { 'task_started_at' => START }, pull: head_pull)}\n"
  def head_pull = { 'head' => { 'sha' => HEAD } }
  def bounded(heads, kept) = Shaka::ThroughputStats.bounded_first_push(heads, true, { 'first_push' => kept })

  def one_commit(pushed, created)
    commit = gql(HEAD, pushed, [check_run('validate', 'SUCCESS')])
    commit['checkSuites']['nodes'][0]['createdAt'] = created
    { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 1, 'nodes' => [{ 'commit' => commit }] } }
  end

  def push_times = { 'task_started_at' => START, 'head_pushed_at' => PUSH }

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
  def check(name, completed_at, bucket = 'pass') = { 'name' => name, 'bucket' => bucket, 'completedAt' => completed_at }

  def nodes(commits) = commits.map { |commit| { 'commit' => commit } }
  def history = { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 2, 'nodes' => nodes(commit_runs) } }

  def started_commit
    commit = gql(HEAD, nil, [check_run('validate', 'SUCCESS').merge('startedAt' => LATER.iso8601)])
    commit['checkSuites']['nodes'][0]['createdAt'] = PUSH.iso8601
    commit['checkSuites']['nodes'] << { 'createdAt' => '0001-01-01T00:00:00Z', 'checkRuns' => { 'nodes' => [] } }
    commit
  end

  def gql(oid, pushed, runs)
    { 'oid' => oid, 'pushedDate' => pushed, 'checkSuites' => { 'nodes' => [{ 'checkRuns' => { 'nodes' => runs } }] } }
  end

  class FakeGitHub
    attr_reader :patches
    attr_accessor :moved_pull

    def initialize(body, pull, checks)
      @body = body
      @pull = pull
      @checks = checks
      @patches = []
    end

    def repository = 'owner/repo'
    def number = 7
    def check_times = @checks

    def graphql(*)
      @graphql_calls = (@graphql_calls || 0) + 1
      { 'repository' => { 'pullRequest' => @graphql_calls > 1 && @moved_pull ? @moved_pull : @pull } }
    end

    def api(_path, method: 'GET', fields: {}, expected: Hash, headers: []) # rubocop:disable Lint/UnusedMethodArgument
      return { 'body' => @body } unless method == 'PATCH'

      @patches << (@body = fields.fetch(:body))
      { 'body' => @body }
    end
  end
end
