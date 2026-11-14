# frozen_string_literal: true

require_relative 'publication/task_timing'
require_relative 'publication/throughput_stats'

module Shaka
  # Inspect the managed body GitHub returned after its write, excluding human-authored text.
  module PublishedTiming
    METRICS_START = /^#{Regexp.escape(UsageEstimate::MARKER)}\r?\n/

    module_function

    def from_publication(published, head:, timeline:, lookup_note:)
      check(published['body'], head: published.dig('head', 'sha') || head, timeline:, lookup_note:)
    end

    def check(body, head:, timeline:, lookup_note: nil, now: Time.now.utc)
      region = metrics_region(body)
      state = ThroughputStats.read(region)
      issue = problem(state, body, head, timeline, now)
      return result('unverified', issue, lookup_note) if issue

      metric = ThroughputStats.took(state).delete_prefix(' · ')
      return result('unverified', 'Stored elapsed time does not match the timing record.', lookup_note) unless
        region[ThroughputStats::COST]&.end_with?(" · #{metric}")

      summarize(state, metric, lookup_note || evidence_gap(state, timeline, now))
    rescue Error
      result('unverified', 'Stored timing record is unreadable.', lookup_note)
    end

    def metrics_region(body) = Publishing.managed_region(body).to_s.split(METRICS_START, 2)[1].to_s

    def evidence_gap(state, timeline, now)
      endpoint_gap(state, timeline, now) ||
        ('Task start could not be verified.' if state['t0'] && !timeline['task_started_at'])
    end

    def endpoint_gap(state, timeline, now)
      return 'GitHub merge time unavailable.' if timeline['merged_pr'] && !timeline['merged']

      endpoint = state['t3'] ? %w[t3 merged] : %w[t2 ready_at]
      recorded = state[endpoint.first]
      return unless recorded

      observed = timeline[endpoint.last]
      return if observed && observed == TaskTiming.timestamp(recorded, now)

      'The elapsed endpoint could not be verified from current GitHub evidence.'
    end

    # Publication already checks that GitHub stored the submitted body. Check the
    # selected start and the visible metric without rebuilding the CI timeline.
    def problem(state, body, head, timeline, now)
      return 'No stored timing record for the published head.' unless head && state&.fetch('head', nil) == head
      return unless (started = timeline['task_started_at'])

      marker = TaskTiming.read(body, now)['task_started_at']
      return if marker == started && TaskTiming.timestamp(state['t0'], now) == started

      'Stored task start does not match the selected timestamp.'
    end

    def summarize(state, metric, lookup_note)
      return result('unavailable', lookup_note, nil, metric) if lookup_note
      return result('pending', 'CI readiness time not recorded yet.', lookup_note, metric) if metric == 'ready pending'
      return result('matched', nil, lookup_note, metric) unless metric.end_with?('UNKNOWN')

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
