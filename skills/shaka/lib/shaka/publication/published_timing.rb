# frozen_string_literal: true

require_relative 'task_timing'
require_relative 'throughput_stats'

module Shaka
  # Inspect the managed body GitHub returned after its write, excluding human-authored text.
  module PublishedTiming
    module_function

    def check(body, head:, started:, lookup_note: nil, now: Time.now.utc)
      region = Publishing.managed_region(body).to_s
      state = ThroughputStats.read(region)
      issue = problem(state, body, head, started, now)
      return result('unverified', issue, lookup_note) if issue

      metric = ThroughputStats.took(state).delete_prefix(' · ')
      return result('unverified', 'Stored elapsed time does not match the timing record.', lookup_note) unless
        region[ThroughputStats::COST]&.end_with?(" · #{metric}")

      summarize(state, metric, lookup_note)
    rescue Error
      result('unverified', 'Stored timing record is unreadable.', lookup_note)
    end

    # Publication already checks that GitHub stored the submitted body. Check the
    # selected start and the visible metric without rebuilding the CI timeline.
    def problem(state, body, head, started, now)
      return 'No stored timing record for the published head.' unless head && state&.fetch('head', nil) == head
      return unless started

      marker = TaskTiming.read(body, now)['task_started_at']
      return if marker == started && TaskTiming.timestamp(state['t0'], now) == started

      'Stored task start does not match the selected timestamp.'
    end

    def summarize(state, metric, lookup_note)
      return result('unavailable', lookup_note, nil, metric) if lookup_note
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
