# frozen_string_literal: true

require_relative 'test_helper'
require 'time'
require 'shaka/publication/timings_details'

# The timings separate the time between checkpoints from each wait on a person, as GitHub's labels record it.
class TimingsDetailsTest < Minitest::Test
  OPENED = Time.utc(2026, 10, 18, 8, 0)

  def at(minutes) = OPENED + (minutes * 60)
  def label(name, minutes, added: true) = { 'name' => name, 'added' => added, 'at' => at(minutes) }

  def timeline(labels: [], merged: nil, first_commit: nil, closed: nil)
    { 'opened' => OPENED, 'first_commit' => first_commit, 'merged' => merged, 'closed' => closed, 'labels' => labels }
  end

  def lengths(detail) = rows(detail).map { |row| row.values_at(0, 3) }

  def rows(detail) = detail['body'].lines.grep(/\A\| (?!Stretch|---)/).map { |line| line.split('|').map(&:strip)[1..] }

  def test_alternates_work_and_waits_and_ends_the_last_wait_at_the_merge
    labels = [label('awaiting-answer', 10), label('awaiting-answer', 70, added: false),
              label('awaiting-merge-approval', 100)]
    detail = Shaka::TimingsDetails.new(timeline(first_commit: at(-30), merged: at(800), labels:)).detail
    assert_equal [['Before the pull request', '30m'], ['Between checkpoints', '10m'],
                  ['Waiting on a person: answer', '1h 0m'], ['Between checkpoints', '30m'],
                  ['Waiting on a person: merge approval', '11h 40m']], lengths(detail)
    assert_includes rows(detail).last[2], 'merged'
    assert_includes detail['body'], '1h 10m between checkpoints · 12h 40m waiting on a person in 2 waits'
  end

  def test_the_summary_shows_the_same_totals_as_the_body
    detail = Shaka::TimingsDetails.new(timeline(merged: at(60))).detail
    assert_equal 'Timings · 1h 0m between checkpoints', detail['summary']
    assert detail['body'].start_with?('**Totals:** 1h 0m between checkpoints')
  end

  def test_an_open_wait_runs_until_this_update
    detail = Shaka::TimingsDetails.new(timeline(labels: [label('awaiting-merge-approval', 20)]), now: at(200)).detail
    assert_equal ['Waiting on a person: merge approval', '3h 0m so far'], rows(detail).last.values_at(0, 3)
    assert_equal 'Timings · 20m between checkpoints · 3h 0m waiting on a person in 1 wait', detail['summary']
    assert_includes rows(detail).last[2], 'still waiting'
  end

  def test_open_work_after_a_wait_runs_until_this_update
    labels = [label('awaiting-resume', 5), label('awaiting-resume', 65, added: false)]
    detail = Shaka::TimingsDetails.new(timeline(labels:), now: at(90)).detail
    assert_equal ['Between checkpoints', '25m so far'], rows(detail).last.values_at(0, 3)
    assert_includes rows(detail).last[2], 'this update'
  end

  # A label on for seconds may be a quick reply or the agent relabeling; the history cannot tell, so it shows.
  def test_a_wait_under_a_minute_still_counts_as_a_wait
    labels = [{ 'name' => 'awaiting-merge-approval', 'added' => true, 'at' => at(10) },
              { 'name' => 'awaiting-merge-approval', 'added' => false, 'at' => at(10) + 22 }]
    detail = Shaka::TimingsDetails.new(timeline(labels:, merged: at(30))).detail
    assert_equal [['Between checkpoints', '10m'], ['Waiting on a person: merge approval', '<1m'],
                  ['Between checkpoints', '19m']], lengths(detail)
    assert_includes detail['body'], 'in 1 wait'
  end

  def test_overlapping_labels_are_one_wait_until_the_last_comes_off
    labels = [label('awaiting-answer', 10), label('awaiting-resume', 20),
              label('awaiting-answer', 30, added: false), label('awaiting-resume', 50, added: false)]
    detail = Shaka::TimingsDetails.new(timeline(labels:, merged: at(60))).detail
    assert_equal ['Waiting on a person: answer and resume', '40m'], rows(detail)[1].values_at(0, 3)
    assert_equal 'Timings · 20m between checkpoints · 40m waiting on a person in 1 wait', detail['summary']
  end

  def test_a_pull_request_with_no_checkpoints_has_no_waits
    detail = Shaka::TimingsDetails.new(timeline(closed: at(3000))).detail
    assert_equal [['Between checkpoints', '2d 2h']], lengths(detail)
    assert_includes rows(detail).last[2], 'closed'
  end

  def test_a_rebased_first_commit_after_opening_adds_no_earlier_stretch
    detail = Shaka::TimingsDetails.new(timeline(first_commit: at(5), merged: at(30))).detail
    assert_equal ['Between checkpoints'], rows(detail).map(&:first)
  end

  def test_a_recorded_task_start_includes_work_before_the_first_commit
    data = timeline(first_commit: at(-5), merged: at(30)).merge('task_started_at' => at(-60))
    detail = Shaka::TimingsDetails.new(data).detail
    assert_equal ['Before the pull request', '1h 0m'], rows(detail).first.values_at(0, 3)
    assert_includes detail['body'], '1h 30m between checkpoints'
    assert_equal 'Timings · 1h 30m between checkpoints', detail['summary']
  end

  def test_an_unavailable_timeline_is_noted_without_publishing_the_raw_error
    detail = Shaka::TimingsDetails.new({ 'unavailable' => 'gh: HTTP 502 from api.github.com' }).detail
    assert_equal 'Timings · timeline unavailable', detail['summary']
    assert_includes detail['body'], 'did not supply'
    refute_includes detail['body'], 'HTTP 502'
  end

  def answered(waits)
    (0...waits).flat_map do |index|
      [label('awaiting-answer', index * 10), label('awaiting-answer', (index * 10) + 5, added: false)]
    end
  end

  def test_only_the_latest_rows_show_while_the_totals_count_every_stretch
    detail = Shaka::TimingsDetails.new(timeline(labels: answered(40), merged: at(400))).detail
    assert_equal Shaka::TimingsDetails::MAX_ROWS, rows(detail).size
    assert_includes detail['body'], 'of 80 stretches'
    assert_includes detail['body'], '3h 20m waiting on a person in 40 waits'
    assert_equal 'Timings · 3h 20m between checkpoints · 3h 20m waiting on a person in 40 waits', detail['summary']
  end

  def test_a_just_opened_wait_shows_although_it_is_under_a_minute
    detail = Shaka::TimingsDetails.new(timeline(labels: [label('awaiting-answer', 30)]), now: at(30)).detail
    assert_equal ['Waiting on a person: answer', '<1m so far'], rows(detail).last.values_at(0, 3)
  end

  def test_measured_steps_stay_separate_from_the_timeline_totals
    step = { 'id' => 'a' * 16, 'command' => 'evidence run', 'at' => OPENED.iso8601,
             'duration_ms' => 120_000, 'exit' => 0 }
    data = timeline(merged: at(60)).merge('steps' => [step], 'dropped_steps' => 2)
    detail = Shaka::TimingsDetails.new(data).detail
    assert_equal 'Timings · 1h 0m between checkpoints', detail['summary']
    assert_includes detail['body'], '**Measured steps:** Validation 2m 0s (1 run)'
    assert_includes detail['body'], '2 older steps are no longer kept'
    assert_includes detail['body'], 'A step can overlap the stretches above.'
  end

  def test_a_hand_written_timings_item_is_refused
    assert_raises(Shaka::Error) do
      Shaka::TimingsDetails.refuse_free_form!([{ 'summary' => 'Timings', 'body' => 'x' }])
    end
    Shaka::TimingsDetails.refuse_free_form!([{ 'summary' => 'Timing-safe comparison', 'body' => 'x' }])
  end
end
