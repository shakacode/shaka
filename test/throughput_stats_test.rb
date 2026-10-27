# frozen_string_literal: true

require_relative 'throughput_helper'

# Spend and build latency stay in one marked block, and unknown times are never zero.
class ThroughputStatsTest < Minitest::Test
  include ThroughputHelper

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

  def test_a_duplicate_block_or_a_zero_round_count_is_refused
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update("#{describe}\n#{describe}", 'spend' => '$1.00') }
    error = assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(describe, 'rounds' => 0) }
    assert_includes error.message, 'positive'
  end

  def test_a_value_that_ends_the_html_comment_is_refused
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(describe, 'spend' => 'x-->y') }
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update(describe, 'spend' => 'x--!>y') }
  end

  def test_a_body_without_a_block_and_crlf_outside_the_block_stay_unchanged
    assert_equal 'no block here', Shaka::ThroughputStats.update('no block here', 'spend' => '$1.00')
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

  private

  def republish(merged, sha, pushed)
    times = { 'task_started_at' => START, 'head_pushed_at' => pushed }
    times['merged'] = merged if merged
    describe('$4.12', timeline: times, pull: { 'head' => { 'sha' => sha }, 'body' => filled_block })
  end
end
