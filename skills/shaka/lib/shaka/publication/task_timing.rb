# frozen_string_literal: true

require_relative '../error'
require_relative 'timeline_steps'
require_relative 'run_summary'
require_relative 'time_zone'
require_relative 'throughput_line'
require_relative 'usage_details'

module Shaka
  # Retains the task start, supplied or read from a usage report, separately from GitHub's first commit.
  module TaskTiming
    extend ThroughputLine

    MARKER = /^<!-- task-timing (\{[^\r\n]*\}) -->\r?$/
    FIELDS = %w[task_started_at first_validation_at].freeze

    module_function

    def attach_lifecycle(timeline, pull, now: Time.now.utc)
      timeline['opened'] ||= timestamp(pull['created_at'], now)
      return unless pull['merged'] == true

      timeline['merged_pr'] = true
      timeline['merged'] ||= timestamp(pull['merged_at'], now)
    end

    def attach(timeline, content, pull, now: Time.now.utc)
      saved = TimelineSteps.same_repository?(pull) ? read(pull['body'], now) : {}
      saved.delete('task_started_at') if after_opening?(saved['task_started_at'], timeline)
      started = start(content['task_started_at'], saved, timeline, now) || usage_start(content, timeline, now)
      first = first_validation(timeline, saved, now)
      timeline.merge('task_started_at' => started, 'first_validation_at' => first)
    end

    def start(supplied, saved, timeline, now)
      return saved['task_started_at'] if supplied.nil?

      started = timestamp(supplied, now)
      return started if started && !after_opening?(started, timeline)

      raise Error, 'Publication task_started_at needs an ISO 8601 timestamp no later than PR opening or now.'
    end

    def after_opening?(started, timeline)
      started && timeline['opened'] && started > timeline['opened']
    end

    # A report covering the whole task opens when the work did, so it stands in for a start nobody supplied.
    # One that opens after the pull request came from a later chat and cannot date the task.
    def usage_start(content, timeline, now)
      usage = content['usage']
      records = usage.is_a?(Hash) ? Array(usage['records']).grep(Hash) : []
      started = records.filter_map { |record| timestamp(record['from'], now) if whole_task?(record) }.min
      started unless started && timeline['opened'] && started > timeline['opened']
    end

    def whole_task?(record) = record['covers_task'] == true && record['contribution'] == 'implementation'

    def first_validation(timeline, saved, now)
      previous = saved['first_validation_at']
      return previous if timeline.fetch('dropped_steps', 0).positive?

      times = Array(timeline['steps']).filter_map do |step|
        timestamp(step['at'], now) if step['command'] == 'evidence run'
      end
      [previous, *times].compact.min
    end

    def read(body, now)
      region = Publishing.managed_region(body).to_s
      metrics = UsageEstimate.metrics(region)
      records = (metrics ? timing_details(metrics) : region).scan(MARKER)
      line = records.first.first if records.one?
      data = line ? JSON.parse(line) : {}
      return {} unless data.is_a?(Hash)

      FIELDS.to_h { |key| [key, timestamp(data[key], now)] }.compact
    rescue JSON::ParserError
      {}
    end

    def timing_details(metrics)
      pattern = %r{^<summary>Timings · [^\r\n]+</summary>\r?\n\r?\n
                   (?=<!--\ shaka:stats\ )(.*?)^</details>}mx
      sections = metrics.scan(pattern)
      sections.one? ? sections.first.first : ''
    end

    def timestamp(value, now)
      return unless value.is_a?(String) && value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)

      time = Time.iso8601(value).utc.round(9)
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
      data = timeline.slice(*FIELDS).compact.transform_values { |time| iso_timestamp(time) }
      "<!-- task-timing #{JSON.generate(data)} -->" unless data.empty?
    end
  end
end
