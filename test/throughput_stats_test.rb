# frozen_string_literal: true

require_relative 'throughput_helper'

# Spend follows the model line, the intervals open Timings, and unknown times are never zero.
class ThroughputStatsTest < Minitest::Test
  include ThroughputHelper

  PENDING = '**This head:** Prompt to CI UNKNOWN · CI to ready pending · Ready to merged pending'

  def test_the_model_line_shows_spend_and_timings_shows_the_intervals
    rendered = describe
    assert_match(/\A🤖 Codex · OpenAI · gpt-5\.6-terra · low - AI spend: UNKNOWN\n\n/, rendered)
    assert_includes rendered, PENDING
    assert_operator rendered.index('<summary>Timings'), :<, rendered.index(PENDING)
    refute_includes rendered, 'AI spend: $0'
    refute_includes rendered, 'Usage and cost ·'
    assert_includes describe('$0.00'), 'AI spend: $0.00'
  end

  def test_prompt_to_ci_runs_from_the_task_start_to_the_first_check_start
    started = { 'task_started_at' => START, 'ci_started_at' => PUSH }
    assert_includes describe('$4.12', timeline: started), "low - AI spend: $4.12\n"
    assert_includes describe('$4.12', timeline: started), '**This head:** Prompt to CI 38m'
    assert_includes describe('$4.12', timeline: started), '| openai | $4.12 |'
    short = { 'task_started_at' => START, 'ci_started_at' => START + 30 }
    assert_includes describe('UNKNOWN', timeline: short), 'Prompt to CI <1m'
    assert_includes describe('UNKNOWN', timeline: { 'task_started_at' => PUSH, 'ci_started_at' => START }),
                    'Prompt to CI UNKNOWN'
    assert_includes describe('UNKNOWN', timeline: { 'task_started_at' => START }), 'Prompt to CI pending'
  end

  def test_the_publisher_note_stays_under_the_stats_line
    noted = content.merge('publisher_note' => 'Served model unavailable.')
    rendered = Shaka::Publication.description(noted)
    assert_operator rendered.index('AI spend:'), :<, rendered.index('_Served model unavailable._')
  end

  def test_updating_the_block_is_idempotent_and_leaves_the_surrounding_text
    body = "Keep this.\n\n#{describe('$4.12', timeline: push_times, pull: head_pull)}\nAnd this.\n"
    changes = { 't2' => READY.iso8601, 'head' => HEAD }
    updated = Shaka::ThroughputStats.update(body, changes)
    assert_equal updated, Shaka::ThroughputStats.update(updated, changes)
    assert updated.start_with?("Keep this.\n\n") && updated.end_with?("\nAnd this.\n")
    assert_includes updated, 'CI to ready 41m · Ready to merged pending'
    assert_includes updated, "low - AI spend: $4.12\n"
    assert_includes updated, "**Estimated token costs:** $4.12 · ready in 1h 19m\n"
    assert_equal 1, updated.scan('<!-- shaka:stats ').size
  end

  def test_a_duplicate_block_is_refused
    assert_raises(Shaka::Error) { Shaka::ThroughputStats.update("#{describe}\n#{describe}", 'spend' => '$1.00') }
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

  def test_a_damaged_block_in_the_body_does_not_stop_republication
    damaged = "<!-- shaka:stats {not json} -->\n"
    rendered = describe('$4.12', timeline: push_times, pull: { 'head' => { 'sha' => HEAD }, 'body' => damaged })
    assert_includes rendered, '**This head:** Prompt to CI 38m · CI to ready pending'
  end

  def test_a_backslash_in_a_carried_value_survives_a_rewrite
    once = Shaka::ThroughputStats.update(describe, 'spend' => 'a\x')
    assert_equal 'a\x', Shaka::ThroughputStats.read(Shaka::ThroughputStats.update(once, 't2' => 'UNKNOWN'))['spend']
  end

  def test_a_carried_value_that_ends_the_comment_is_not_written_back
    hostile = "<!-- shaka:stats {\"head\":\"#{HEAD}\",\"t2\":\"--> **x**\"} -->\n**This head:** x\n"
    rendered = describe('$4.12', timeline: push_times, pull: { 'head' => { 'sha' => HEAD }, 'body' => hostile })
    refute_includes rendered, '**x**'
    assert_equal hostile, Shaka::ThroughputStats.refresh_spend(hostile, '$1.00')
  end

  def test_a_carried_time_that_does_not_parse_is_not_kept
    edited = "<!-- shaka:stats {\"head\":\"#{HEAD}\",\"t1\":\"!\"} -->\n**This head:** x\n"
    rendered = describe('$4.12', timeline: push_times, pull: { 'head' => { 'sha' => HEAD }, 'body' => edited })
    assert_includes rendered, 'Prompt to CI 38m'
  end

  def test_republishing_keeps_ready_time_only_for_the_same_head
    assert_includes republish(MERGED, HEAD, PUSH), 'CI to ready 41m · Ready to merged 2h 5m'
    assert_includes republish(MERGED, HEAD, PUSH), "**Estimated token costs:** $4.12 · merged in 3h 24m\n"
    assert_includes republish(nil, NEXT, READY), 'Prompt to CI 1h 19m · CI to ready pending'
  end

  def test_a_merged_pull_request_without_a_ready_time_shows_unknown
    merged = { 'task_started_at' => START, 'ci_started_at' => PUSH, 'merged' => MERGED }
    assert_includes describe('UNKNOWN', timeline: merged), 'CI to ready UNKNOWN · Ready to merged UNKNOWN'
  end

  private

  def republish(merged, sha, pushed)
    times = { 'task_started_at' => START, 'ci_started_at' => pushed }
    times['merged'] = merged if merged
    describe('$4.12', timeline: times, pull: { 'head' => { 'sha' => sha }, 'body' => filled_block })
  end
end

# A refresh rewrites the spend and the time in place, keeping line endings and leaving a damaged block alone.
class ThroughputRefreshTest < Minitest::Test
  include ThroughputHelper

  def test_a_usage_refresh_keeps_the_time_on_the_cost_line
    refreshed = Shaka::UsageEstimate.refresh(filled_block, 'estimate' => '$9.00')
    updated = Shaka::ThroughputStats.refresh_spend(refreshed, '$9.00')
    assert_includes updated, "**Estimated token costs:** $9.00 · ready in 1h 19m\n"
    assert_includes updated, "low - AI spend: $9.00\n"
  end

  def test_a_spend_refresh_leaves_a_damaged_block_alone
    damaged = "Keep.\n<!-- shaka:stats {not json} -->\n**This head:** x\n"
    assert_equal damaged, Shaka::ThroughputStats.refresh_spend(damaged, '$1.00')
  end

  def test_a_spend_refresh_updates_the_model_line_even_with_a_damaged_block
    damaged = "🤖 Codex - AI spend: $4.12\n\n<!-- shaka:stats {not json} -->\n**This head:** x\n"
    assert_includes Shaka::ThroughputStats.refresh_spend(damaged, '$9.00'), "🤖 Codex - AI spend: $9.00\n"
  end

  def test_a_crlf_block_is_read_and_updated_with_its_line_endings
    crlf = "Keep.\r\n#{filled_block.gsub("\n", "\r\n")}\r\nMore.\r\n"
    assert_equal READY.iso8601, Shaka::ThroughputStats.read(crlf)['t2']
    updated = Shaka::ThroughputStats.update(crlf, 'spend' => '$5.00')
    assert_includes updated, "-->\r\n**This head:**"
    assert_includes updated, "low - AI spend: $5.00\r\n"
    assert_includes updated, "**Estimated token costs:** $4.12 · ready in 1h 19m\r\n"
    assert updated.end_with?("\r\nMore.\r\n")
  end
end
