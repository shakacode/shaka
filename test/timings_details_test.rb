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
    assert_includes detail['summary'], '1h 10m between checkpoints · 12h 40m waiting on a person in 2 waits'
  end

  def test_an_open_wait_runs_until_this_update
    detail = Shaka::TimingsDetails.new(timeline(labels: [label('awaiting-merge-approval', 20)]), now: at(200)).detail
    assert_equal ['Waiting on a person: merge approval', '3h 0m so far'], rows(detail).last.values_at(0, 3)
    assert_includes rows(detail).last[2], 'still waiting'
  end

  def test_open_work_after_a_wait_runs_until_this_update
    labels = [label('awaiting-resume', 5), label('awaiting-resume', 65, added: false)]
    detail = Shaka::TimingsDetails.new(timeline(labels:), now: at(90)).detail
    assert_equal ['Between checkpoints', '25m so far'], rows(detail).last.values_at(0, 3)
    assert_includes rows(detail).last[2], 'this update'
  end

  def test_a_relabel_under_a_minute_counts_as_time_between_checkpoints
    labels = [{ 'name' => 'awaiting-merge-approval', 'added' => true, 'at' => at(10) },
              { 'name' => 'awaiting-merge-approval', 'added' => false, 'at' => at(10) + 22 }]
    detail = Shaka::TimingsDetails.new(timeline(labels:, merged: at(30))).detail
    assert_equal [['Between checkpoints', '30m']], lengths(detail)
    refute_includes detail['summary'], 'waiting'
  end

  def test_overlapping_labels_are_one_wait_until_the_last_comes_off
    labels = [label('awaiting-answer', 10), label('awaiting-resume', 20),
              label('awaiting-answer', 30, added: false), label('awaiting-resume', 50, added: false)]
    detail = Shaka::TimingsDetails.new(timeline(labels:, merged: at(60))).detail
    assert_equal ['Waiting on a person: answer and resume', '40m'], rows(detail)[1].values_at(0, 3)
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

  def test_an_unavailable_timeline_says_why_instead_of_blocking_publication
    detail = Shaka::TimingsDetails.new({ 'unavailable' => 'GraphQL failed.' }).detail
    assert_includes detail['summary'], 'unavailable'
    assert_includes detail['body'], 'GraphQL failed.'
  end

  def test_a_hand_written_timings_item_is_refused
    assert_raises(Shaka::Error) do
      Shaka::TimingsDetails.refuse_free_form!([{ 'summary' => 'Timings', 'body' => 'x' }])
    end
    Shaka::TimingsDetails.refuse_free_form!([{ 'summary' => 'Timing-safe comparison', 'body' => 'x' }])
  end
end
