# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/timings_report'

# Merged pull requests' carried timings add up into a ranked list and a weekly trend.
class TimingsReportTest < Minitest::Test
  def test_ranks_buckets_and_groups_weeks
    report = JSON.parse(run_report(mixed_pulls, '--format', 'json'))

    assert_equal [4, 2], report.values_at('merged_pull_requests', 'with_timings')
    assert_equal([['Validation', 800_000], ['Validation phase: tests', 500_000], ['Local review', 60_000]],
                 report['buckets'].map { |bucket| bucket.values_at('name', 'total_ms') })
    assert_equal([['2026-11-02', 1], ['2026-11-09', 0]],
                 report['weeks'].map { |week| week.values_at('week', 'failed_validations') })
  end

  # Agent working sums the agent rows, so it is left out of the ranking and kept in the weekly trend.
  def test_agent_working_stays_out_of_the_ranking
    pulls = [pull_with_agent_time]

    report = JSON.parse(run_report(pulls, '--format', 'json'))

    assert_equal(['Agent: model', 'Agent: validation', 'Validation'], report['buckets'].map { |bucket| bucket['name'] })
    assert_equal 900_000, report['weeks'].first['median_agent_working_ms']
  end

  def test_a_pull_request_that_dropped_steps_is_named_partial
    pulls = [pull(1, '2026-11-03T12:00:00Z', [step(1000)])]
    pulls.first['body'] = pulls.first['body'].sub('"dropped":0', '"dropped":3')

    assert_includes run_report(pulls), '1 kept only their latest steps, so their step totals are low.'
  end

  # Two of three pull requests had no review; the week's review median covers the one that did.
  def test_a_weekly_median_covers_only_pull_requests_with_that_step
    pulls = [pull(2, '2026-11-11T12:00:00Z', [step(1000), review(60_000)]),
             pull(5, '2026-11-11T13:00:00Z', [step(2000)]), pull(6, '2026-11-11T14:00:00Z', [step(3000)])]

    report = JSON.parse(run_report(pulls, '--format', 'json'))

    assert_equal 60_000, report['weeks'].first['median_review_ms']
  end

  def test_a_week_without_a_step_shows_no_data_rather_than_zero
    report = JSON.parse(run_report([pull(1, '2026-11-03T12:00:00Z', [step(1000)])], '--format', 'json'))

    assert_nil report['weeks'].first['median_review_ms']
    assert_includes run_report([pull(1, '2026-11-03T12:00:00Z', [step(1000)])]), '| 1s | — |'
  end

  def test_task_start_dates_the_time_to_merge
    report = JSON.parse(run_report([pull(1, '2026-11-03T12:00:00Z', [step(1000)])], '--format', 'json'))

    assert_equal 2 * 3_600_000, report['slowest'].first['task_to_merge_ms']
  end

  def test_markdown_lists_the_ranked_table_first
    output = run_report([pull(1, '2026-11-03T12:00:00Z', [step(600_000)])])

    assert_includes output, '| Validation | 10m | 1 | 10m | 10m |'
    assert_includes output, '1 of 1 merged pull requests carried timings'
  end

  def test_a_missing_gh_reports_an_error_instead_of_a_trace
    arguments = %w[report --repository shakacode/shaka --since 2026-11-01]
    _output, error = capture_io do
      assert_equal 1, Shaka::TimingsReport.run(arguments, fetch: ->(_options) { raise Errno::ENOENT, 'gh' })
    end

    assert_includes error, 'shaka timings: No such file or directory - gh'
  end

  def test_refuses_a_missing_repository_or_start
    _output, error = capture_io { assert_equal 1, Shaka::TimingsReport.run(%w[report --since 2026-11-01]) }

    assert_includes error, 'Usage: shaka timings report'
  end

  private

  def pull_with_agent_time
    session = { 'id' => 'a' * 16, 'host' => 'Codex', 'active_ms' => 900_000, 'model_ms' => 600_000, 'waiting_ms' => 0,
                'between_turns_ms' => 0, 'tools' => { 'validation' => 300_000 } }
    pull(1, '2026-11-03T12:00:00Z', [step(1000)]).tap do |made|
      made['body'] = made['body'].sub('<!-- shaka:end -->', "#{Shaka::AgentTime.hidden([session])}\n<!-- shaka:end -->")
    end
  end

  # Two with timings, one from a fork, and one without timings.
  def mixed_pulls
    [pull(1, '2026-11-03T12:00:00Z', [step(600_000, phases: { 'tests' => 400_000 }, exit: 1)]),
     pull(2, '2026-11-11T12:00:00Z', [step(200_000, phases: { 'tests' => 100_000 }), review(60_000)]),
     pull(3, '2026-11-11T13:00:00Z', [step(100_000)], cross: true), pull(4, '2026-11-11T14:00:00Z', [])]
  end

  def run_report(pulls, *extra)
    output, = capture_io do
      arguments = ['report', '--repository', 'shakacode/shaka', '--since', '2026-11-01', *extra]
      assert_equal 0, Shaka::TimingsReport.run(arguments, fetch: ->(_options) { pulls })
    end
    output
  end

  def pull(number, merged, steps, cross: false)
    timing = '<!-- task-timing {"task_started_at":"2026-11-03T10:00:00Z"} -->'
    body = "<!-- shaka:begin -->\n#{Shaka::TimelineSteps.hidden(steps)}\n#{timing if number == 1}\n<!-- shaka:end -->"
    { 'number' => number, 'url' => "https://github.com/shakacode/shaka/pull/#{number}", 'mergedAt' => merged,
      'createdAt' => '2026-11-03T11:00:00Z', 'isCrossRepository' => cross, 'body' => body }
  end

  def step(duration, phases: nil, exit: 0)
    { 'id' => format('%016x', duration), 'command' => 'evidence run', 'check' => 'validate',
      'at' => '2026-11-03T10:30:00Z', 'duration_ms' => duration, 'exit' => exit, 'phases' => phases }.compact
  end

  def review(duration)
    { 'id' => format('%016x', duration + 1), 'command' => 'review run', 'at' => '2026-11-03T10:40:00Z',
      'duration_ms' => duration, 'exit' => 0 }
  end
end
