# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/task_timing'

class TaskTimingTest < Minitest::Test
  START = '2026-10-18T07:00:00Z'
  VALIDATION = '2026-10-18T07:45:00Z'
  NOW = Time.utc(2026, 10, 18, 9)

  def pull(body = '', fork: false)
    { 'body' => "<!-- shaka:begin -->\n#{body}\n<!-- shaka:end -->",
      'head' => { 'repo' => { 'full_name' => fork ? 'other/repo' : 'owner/repo' } },
      'base' => { 'repo' => { 'full_name' => 'owner/repo' } } }
  end

  def timeline
    { 'opened' => NOW - 3600, 'steps' => [{ 'command' => 'evidence run', 'at' => VALIDATION }] }
  end

  def attach(content = {}, existing = pull, data = timeline)
    Shaka::TaskTiming.attach(data, content, existing, now: NOW)
  end

  def recorded = attach('task_started_at' => START)

  def test_start_and_first_validation_survive_an_update_without_steps
    original = recorded
    updated = attach({}, pull(Shaka::TaskTiming.hidden(original)), timeline.merge('steps' => []))
    assert_equal original.values_at(*Shaka::TaskTiming::FIELDS), updated.values_at(*Shaka::TaskTiming::FIELDS)
  end

  def test_retention_does_not_replace_the_first_validation_with_a_later_one
    data = timeline.merge('dropped_steps' => 5, 'steps' => [{ 'command' => 'evidence run', 'at' => NOW.iso8601 }])
    updated = attach({}, pull(Shaka::TaskTiming.hidden(recorded)), data)
    assert_equal Time.iso8601(VALIDATION), updated['first_validation_at']
    assert_nil attach({}, pull, data)['first_validation_at']
  end

  def test_missing_start_is_not_inferred_from_a_commit_or_validation
    assert_nil attach['task_started_at']
    assert_equal Time.iso8601(VALIDATION), attach['first_validation_at']
  end

  def test_start_requires_a_timestamp_with_timezone_before_opening
    [123, 'yesterday', '2026-10-18T07:00:00', '2026-10-19T07:00:00Z', '2026-10-18T08:01:00Z'].each do |value|
      assert_raises(Shaka::Error) { attach('task_started_at' => value) }
    end
    assert_equal Time.iso8601(START), attach('task_started_at' => '2026-10-18T09:00:00+02:00')['task_started_at']
  end

  def test_earlier_validation_keeps_publication_available_and_retains_both_timestamps
    data = timeline.merge('steps' => [{ 'command' => 'evidence run', 'at' => '2026-10-18T06:59:00Z' }])
    updated = attach({}, pull(Shaka::TaskTiming.hidden(recorded)), data)
    assert_includes Shaka::TaskTiming.summary(updated), 'predates task start; interval unavailable'
    assert_equal Time.iso8601(START), updated['task_started_at']
    repeated = attach({ 'task_started_at' => START }, pull(Shaka::TaskTiming.hidden(updated)), data)
    assert_equal updated, repeated
  end

  def test_forks_and_markers_outside_the_managed_region_carry_no_task_start
    marker = Shaka::TaskTiming.hidden(recorded)
    assert_nil attach({}, pull(marker, fork: true))['task_started_at']
    assert_nil attach({}, pull.merge('body' => marker))['task_started_at']
  end

  def test_bad_saved_metadata_is_ignored
    ['<!-- task-timing {oops} -->', '<!-- task-timing [] -->',
     '<!-- task-timing {"task_started_at":"yesterday"} -->'].each do |marker|
      assert_nil attach({}, pull(marker))['task_started_at']
    end
  end

  def test_a_timeline_read_failure_keeps_task_timing_for_the_next_update
    result = attach({}, pull(Shaka::TaskTiming.hidden(recorded)), { 'unavailable' => 'offline' })
    assert_equal Time.iso8601(START), result['task_started_at']
    assert_equal Time.iso8601(VALIDATION), result['first_validation_at']
  end
end
