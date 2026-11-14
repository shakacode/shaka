# frozen_string_literal: true

require_relative 'publication/task_timing'
require_relative 'publication/throughput_stats'

module Shaka
  # Inspect the managed body GitHub returned after its write, excluding human-authored text.
  module PublishedTiming
    module_function

    def from_publication(published, head:, timeline:, lookup_note:)
      check(published['body'], head: published.dig('head', 'sha') || head, timeline:, lookup_note:)
    end

    def check(body, head:, timeline:, lookup_note: nil, now: Time.now.utc)
      region = metrics_region(body)
      state = ThroughputStats.read(region)
      issue = problem(state, body, head, timeline, now)
      return result('unverified', issue, lookup_note) if issue

      suffix = ThroughputStats.took(state)
      return result('unverified', 'Stored elapsed time does not match the timing record.', lookup_note) unless
        stored_suffix(region) == suffix

      summarize(state, suffix.delete_prefix(' · '), lookup_note || evidence_gap(state, timeline, now))
    rescue Error
      result('unverified', 'Stored timing record is unreadable.', lookup_note)
    end

    def metrics_region(body) = UsageEstimate.metrics(Publishing.managed_region(body).to_s).to_s

    def stored_suffix(region)
      cost = region.match(ThroughputStats::COST)
      cost[0].delete_prefix(cost[1]) if cost
    end

    def evidence_gap(state, timeline, now)
      return 'PR opening time unavailable.' if timeline['task_started_at'] && !timeline['opened']

      endpoint_gap(state, timeline, now) ||
        ('Task start could not be verified.' if state['t0'] && !timeline['task_started_at'])
    end

    def endpoint_gap(state, timeline, now)
      return 'GitHub merge time unavailable.' if timeline.values_at('merged_pr', 'merged') == [true, nil]

      endpoint = state['t3'] ? %w[t3 merged] : %w[t2 ready_at]
      observed = timeline[endpoint.last]
      return 'GitHub readiness time unavailable.' if observed == :unknown

      recorded = state[endpoint.first]
      return unless recorded

      actual = TaskTiming.timestamp(recorded, now)
      return if actual && actual == observed

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
      return result('unavailable', 'Task start timestamp unavailable.', nil) if metric.empty?
      return result('pending', 'CI readiness time not recorded yet.', lookup_note, metric) if metric == 'ready pending'
      return result('matched', nil, lookup_note, metric) unless metric.end_with?('UNKNOWN')

      return result('unavailable', 'Task start timestamp unavailable.', nil, metric) unless
        ThroughputStats.task_started?(state)

      result('unavailable', 'Elapsed time unavailable from the recorded timestamps.', nil, metric)
    end

    def result(status, reason, lookup_note, metric = nil)
      { 'status' => status, 'reason' => reason, 'lookup_note' => lookup_note, 'metric' => metric }.compact
    end
  end
end
