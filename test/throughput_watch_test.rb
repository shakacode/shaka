# frozen_string_literal: true

require_relative 'throughput_helper'
require 'shaka/github/pull_timeline'

# pr watch fills the stats block once per head and never moves a known time later.
class ThroughputWatchTest < Minitest::Test
  include ThroughputHelper

  def test_pr_watch_patches_the_block_once_and_keeps_the_surrounding_text
    github = watch_github
    2.times { publish(github, ['claude-review'], 'one') }
    assert_equal 1, github.patches.size
    patched = github.patches.first
    assert patched.start_with?("Intro.\n\n") && patched.end_with?("\n\nOutro.\n")
    assert_includes patched, 'Prompt to CI 38m · CI to ready 41m'
    assert_includes patched, "low - AI spend: $4.12\n"
    assert_includes patched, "**Estimated token costs:** $4.12 · ready in 1h 19m\n"
  end

  def test_a_watcher_write_drops_the_rendering_preview_marker
    marker = "<!-- shaka:rendering-preview #{HEAD} -->"
    body = "Intro.\n\n#{describe('$4.12', timeline: push_times, pull: head_pull)}\n#{marker}\n"
    github = ThroughputFakeGitHub.new(body, head_page(PUSH.iso8601), [check('validate', READY.iso8601)])
    publish(github, [], 'none')
    refute_includes github.patches.fetch(0), marker
  end

  def test_pr_watch_fills_prompt_to_ci_from_the_check_suite
    body = "Intro.\n\n#{describe('$4.12', timeline: { 'task_started_at' => START }, pull: head_pull)}\n"
    prompted = ThroughputFakeGitHub.new(body, head_page(PUSH.iso8601), [check('validate', READY.iso8601)])
    publish(prompted, [], 'none')
    assert_includes prompted.patches.fetch(0), 'Prompt to CI 38m'
  end

  def test_a_rerun_check_does_not_move_the_ready_time_later
    rerun = ThroughputFakeGitHub.new("Intro.\n\n#{filled_block}\n", head_page(PUSH.iso8601),
                                     [check('validate', (READY + 3600).iso8601)])
    publish(rerun, [], 'none')
    assert_empty rerun.patches
  end

  def test_an_earlier_time_with_another_offset_is_compared_as_a_time
    later = Shaka::ThroughputStats.update(filled_block, 't2' => '2026-10-26T10:00:00-10:00')
    github = ThroughputFakeGitHub.new("Intro.\n\n#{later}\n", head_page(PUSH.iso8601),
                                      [check('validate', READY.iso8601)])
    publish(github, [], 'none')
    assert_includes github.patches.fetch(0), "\"t2\":\"#{READY.iso8601}\""
  end

  def test_a_head_that_moves_before_the_write_is_not_patched
    moved = watch_github
    moved.moved_pull = head_page(PUSH.iso8601).merge('headRefOid' => NEXT)
    publish(moved, [], 'none')
    assert_empty moved.patches
  end

  def test_a_check_start_from_an_earlier_head_is_dropped_when_the_new_head_has_none
    earlier = Shaka::ThroughputStats.update(filled_block, 'head' => NEXT)
    github = ThroughputFakeGitHub.new("Intro.\n\n#{earlier}\n", head_page(nil), [])
    publish(github, [], 'none')
    assert_includes github.patches.fetch(0), 'Prompt to CI pending'
  end

  def test_both_head_queries_ask_for_the_fields_the_check_start_reads
    [Shaka::PrWatch::ThroughputPublisher::QUERY, Shaka::PullTimeline::QUERY].each do |query|
      assert_includes query, Shaka::ThroughputLine::HEAD_CHECKS
    end
  end

  def test_a_ready_time_from_an_earlier_head_is_dropped_for_the_new_head
    earlier = Shaka::ThroughputStats.update(filled_block, 'head' => NEXT)
    github = ThroughputFakeGitHub.new("Intro.\n\n#{earlier}\n", head_page(PUSH.iso8601), [])
    publish(github, [], 'none')
    assert_includes github.patches.fetch(0), 'CI to ready pending'
  end

  def test_a_merge_during_the_watch_records_the_merge_time
    github = MergingFakeGitHub.new("Intro.\n\n#{filled_block}\n", head_page(PUSH.iso8601))
    assert_equal 'closed', watch_until_merged(github)
    patched = github.patches.fetch(0)
    assert_includes patched, 'Ready to merged 2h 5m'
    assert_includes patched, '· merged in 3h 24m'
  end

  def test_a_pull_request_closed_without_merging_is_not_patched
    github = MergingFakeGitHub.new("Intro.\n\n#{filled_block}\n", head_page(PUSH.iso8601), merged_at: nil)
    assert_equal 'closed', watch_until_merged(github)
    assert_empty github.patches
  end

  def test_a_merge_time_is_not_written_into_another_heads_block
    earlier = Shaka::ThroughputStats.update(filled_block, 'head' => NEXT)
    github = MergingFakeGitHub.new("Intro.\n\n#{earlier}\n", head_page(PUSH.iso8601))
    assert_equal 'closed', watch_until_merged(github)
    assert_empty github.patches
  end

  private

  def watch_until_merged(github)
    publisher = Shaka::PrWatch::ThroughputPublisher.new(github, head: HEAD, review_jobs: [], wait: 'none')
    adapters = { clock: -> { 0 }, sleeper: ->(_) { github.merge! }, throughput: publisher,
                 comments: -> { { 'issue_comments' => [], 'review_summaries' => [], 'inline_comments' => [] } } }
    Shaka::PrWatch.new(github, head: HEAD, ci_jobs: [], settings: { interval: 1, timeout: 10, settle: 1 },
                               adapters:).call
  end

  def publish(github, jobs, wait)
    Shaka::PrWatch::ThroughputPublisher.new(github, head: HEAD, review_jobs: jobs, wait:).call(required: ['validate'])
  end

  def watch_github
    body = "Intro.\n\n#{describe('$4.12', timeline: push_times, pull: head_pull)}\n\nOutro.\n"
    ThroughputFakeGitHub.new(body, head_page(PUSH.iso8601),
                             [check('validate', READY.iso8601), check('claude-review', READY.iso8601)])
  end

  def head_page(started)
    { 'headRefOid' => HEAD, 'commits' => { 'nodes' => [{ 'commit' => gql(HEAD, started, []) }] } }
  end
end

# Serves pr watch an open head with a pending required check until GitHub merges or closes it.
class MergingFakeGitHub < ThroughputFakeGitHub
  def initialize(body, pull, merged_at: ThroughputHelper::MERGED.iso8601)
    super(body, pull, [])
    @merged_at = merged_at
  end

  def snapshot = { 'headRefOid' => ThroughputHelper::HEAD, 'state' => @state || 'OPEN' }
  def required_checks = [{ 'name' => 'validate', 'state' => 'PENDING', 'bucket' => 'pending' }]
  def configured_required_checks = []
  def checks = []

  def merge!
    @state = @merged_at ? 'MERGED' : 'CLOSED'
    @pull = @pull.merge('mergedAt' => @merged_at)
  end
end
