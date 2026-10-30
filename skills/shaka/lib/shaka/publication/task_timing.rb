# frozen_string_literal: true

require_relative '../error'
require_relative 'timeline_steps'
require_relative 'run_summary'
require_relative 'time_zone'

module Shaka
  # Retains the agent-reported task start separately from GitHub's first commit.
  module TaskTiming
    MARKER = /^<!-- task-timing (\{.*\}) -->$/
    FIELDS = %w[task_started_at first_validation_at].freeze

    module_function

    def attach(timeline, content, pull, now: Time.now.utc)
      saved = TimelineSteps.same_repository?(pull) ? read(pull['body'], now) : {}
      started = start(content['task_started_at'], saved, timeline, now)
      first = first_validation(timeline, saved, now)
      timeline.merge('task_started_at' => started, 'first_validation_at' => first)
    end

    def start(supplied, saved, timeline, now)
      return saved['task_started_at'] if supplied.nil?

      started = timestamp(supplied, now)
      return started if started && (!timeline['opened'] || started <= timeline['opened'])

      raise Error, 'Publication task_started_at needs an ISO 8601 timestamp no later than PR opening or now.'
    end

    def first_validation(timeline, saved, now)
      previous = saved['first_validation_at']
      return previous if timeline.fetch('dropped_steps', 0).positive?

      times = Array(timeline['steps']).filter_map do |step|
        timestamp(step['at'], now) if step['command'] == 'evidence run'
      end
      [previous, *times].compact.min
    end

    def read(body, now)
      line = Publishing.managed_region(body).to_s[MARKER, 1]
      data = line ? JSON.parse(line) : {}
      return {} unless data.is_a?(Hash)

      FIELDS.to_h { |key| [key, timestamp(data[key], now)] }.compact
    rescue JSON::ParserError
      {}
    end

    def timestamp(value, now)
      return unless value.is_a?(String) && value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)

      time = Time.iso8601(value).utc
      time if time <= now
    rescue ArgumentError
      nil
    end

    def summary(timeline, zone = TimeZone::UTC)
      started, first = timeline.values_at('task_started_at', 'first_validation_at')
      return 'Time before first recorded validation: unavailable; task start was not recorded.' unless started

      origin = "Task start (agent-reported): #{clock(started, zone)}."
      return "#{origin} First recorded validation: unavailable." unless first
      return "#{origin} First recorded validation predates task start; interval unavailable." if first < started

      "**Before first recorded validation:** #{RunSummary.duration((first - started) * 1000)} · #{origin} " \
        "Validation started: #{clock(first, zone)}. This interval overlaps the stretches above."
    end

    def clock(time, zone) = TimeZone.strftime(time, zone, '%Y-%m-%d %H:%M %Z')

    def hidden(timeline)
      data = timeline.slice(*FIELDS).compact.transform_values(&:iso8601)
      "<!-- task-timing #{JSON.generate(data)} -->" unless data.empty?
    end
  end
end
