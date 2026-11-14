# frozen_string_literal: true

require_relative 'task_timing'
require_relative 'throughput_stats'

module Shaka
  # Inspect the managed body GitHub returned after its write, excluding human-authored text.
  module PublishedTiming
    module_function

    def expected(timeline, pull)
      ThroughputStats.state({}, timeline, pull).merge(timeline.slice('task_started_at'))
    end

    def check(body, expected:, lookup_note: nil, now: Time.now.utc)
      region = Publishing.managed_region(body).to_s
      state = ThroughputStats.read(region)
      issue = problem(state, body, expected, now)
      return result('unverified', issue, lookup_note) if issue

      metric = ThroughputStats.took(state).delete_prefix(' · ')
      return result('unverified', 'Stored elapsed time does not match the timing record.', lookup_note) unless
        region[ThroughputStats::COST]&.end_with?(" · #{metric}")

      summarize(state, metric, lookup_note)
    rescue Error
      result('unverified', 'Stored timing record is unreadable.', lookup_note)
    end

    def problem(state, body, expected, now)
      unless state && expected['head'] && state['head'] == expected['head']
        return 'No stored timing record for the published head.'
      end
      return 'Stored CI readiness time does not match the current head.' unless state['t2'] == expected['t2']
      return 'Stored task start does not match the selected timestamp.' unless state['t0'] == expected['t0']

      start_problem(body, expected['task_started_at'], now)
    end

    def start_problem(body, started, now)
      return unless started

      marker = TaskTiming.read(body, now)['task_started_at']
      return if marker&.iso8601 == started.iso8601

      'Stored task start does not match the selected timestamp.'
    end

    def summarize(state, metric, lookup_note)
      return result('pending', 'CI readiness time not recorded yet.', lookup_note, metric) if metric == 'ready pending'
      return result('verified', nil, lookup_note, metric) unless metric.end_with?('UNKNOWN')

      reason = if state['t0'].nil? || state['t0'] == 'UNKNOWN'
                 'Task start timestamp unavailable.'
               else
                 'Elapsed time unavailable from the recorded timestamps.'
               end
      result('unavailable', reason, lookup_note, metric)
    end

    def result(status, reason, lookup_note, metric = nil)
      { 'status' => status, 'reason' => reason, 'lookup_note' => lookup_note, 'metric' => metric }.compact
    end
  end
end
