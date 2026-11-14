# frozen_string_literal: true

require 'time'
require_relative '../publication/phases'
require_relative '../publication/agent_time'
require_relative '../publication/task_timing'
require_relative '../publication/timeline_steps'

module Shaka
  module TimingsReport
    # One merged pull request's measured time, read from the helper's own region of its description.
    # A pull request from a fork is skipped, because its author can edit those numbers.
    module PullRow
      module_function

      def call(pull)
        return if pull['isCrossRepository']

        body = pull['body'].to_s
        steps, dropped = TimelineSteps.read(body)
        sessions = AgentTime.read(body)
        return if steps.empty? && sessions.empty?

        { **pull.slice('number', 'url'), **span(body, pull), 'failed_validations' => failures(steps),
                                                             'dropped_steps' => dropped,
                                                             'buckets' => buckets(steps, sessions) }
      end

      # When it merged and how long it took from the recorded task start, or from opening without one.
      def span(body, pull)
        merged = Time.iso8601(pull['mergedAt'])
        started = TaskTiming.read(body, merged)['task_started_at'] || Time.iso8601(pull['createdAt'])
        { 'merged_at' => merged.iso8601, 'task_to_merge_ms' => ((merged - started) * 1000).round }
      end

      def failures(steps) = steps.count { |step| step['command'] == 'evidence run' && !step['exit'].zero? }

      # Milliseconds per named bucket: each kind of step, each validation phase, and each kind of agent time.
      def buckets(steps, sessions)
        totals = Hash.new(0)
        steps.each { |step| step_time(totals, step) }
        phases = Phases.combine(steps.filter_map { |step| step['phases'] })
        phases.each { |name, value| totals["Validation phase: #{name}"] += value }
        sessions.each { |entry| agent_time(totals, entry) }
        totals.reject { |_name, value| value.zero? }
      end

      def step_time(totals, step)
        totals[TimelineSteps::NAMES.fetch(step['command'])] += step['duration_ms']
        totals['Machine asleep during steps'] += step['duration_ms'] - step['awake_ms'] if step['awake_ms']
      end

      def agent_time(totals, entry)
        totals['Agent working'] += entry['active_ms']
        totals['Agent: model'] += entry['model_ms']
        entry['tools'].each { |category, value| totals["Agent: #{AgentTime::LABELS.fetch(category)}"] += value }
        totals['Agent waiting on questions'] += entry['waiting_ms']
      end
    end
  end
end
