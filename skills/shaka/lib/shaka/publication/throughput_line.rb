# frozen_string_literal: true

require 'json'
require 'time'

module Shaka
  # Renders the one visible throughput line and the durations on it.
  module ThroughputLine
    def line(state) = "#{marker(state)}\n#{visible(state)}"

    private

    def marker(state) = "<!-- shaka:stats #{JSON.generate(ordered(state))} -->"

    def ordered(state) = ThroughputStats::KEYS.filter_map { |key| [key, state[key]] if state.key?(key) }.to_h

    def visible(state)
      "AI spend #{shown_spend(state)} · Prompt to CI #{prompt(state)} · " \
        "CI to ready #{ci(state)} · Ready to merged #{merged(state)}"
    end

    def shown_spend(state)
      text = state['spend']
      text.is_a?(String) && !text.strip.empty? ? text : 'UNKNOWN'
    end

    def prompt(state)
      return 'UNKNOWN' if state['t0'].nil? || state['t1'].nil?

      interval(state['t0'], state['t1'])
    end

    def ci(state)
      return 'pending' if state['t2'].nil?

      "#{ci_span(state)} (#{round_label(state['rounds'])})"
    end

    def ci_span(state)
      return 'UNKNOWN' if state['t2'] == 'UNKNOWN'

      interval(state['first_push'] || state['t1'], state['t2'])
    end

    def round_label(rounds)
      return 'UNKNOWN rounds' unless rounds.is_a?(Integer) && rounds.positive?

      "#{rounds} #{rounds == 1 ? 'round' : 'rounds'}"
    end

    def merged(state)
      return 'pending' if state['t3'].nil?
      return 'UNKNOWN' if unknown_merge?(state)

      interval(state['t2'], state['t3'])
    end

    def unknown_merge?(state) = state['t2'].nil? || state['t2'] == 'UNKNOWN' || state['t3'] == 'UNKNOWN'

    def interval(from, to)
      return 'UNKNOWN' unless ordered_times?(from, to)

      duration(parse_time(to) - parse_time(from))
    end

    def ordered_times?(from, to)
      started = parse_time(from)
      finished = parse_time(to)
      from != 'UNKNOWN' && to != 'UNKNOWN' && started && finished && finished >= started
    end

    def duration(seconds)
      minutes = (seconds / 60).floor
      return '<1m' if minutes < 1
      return "#{minutes}m" if minutes < 60

      clock(minutes)
    end

    def clock(minutes)
      hours, minutes = minutes.divmod(60)
      return "#{hours}h #{minutes}m" if hours < 24

      days, hours = hours.divmod(24)
      "#{days}d #{hours}h"
    end

    def stamp(value)
      return unless parse_time(value)

      value.is_a?(Time) ? value.utc.iso8601 : value
    end

    def parse_time(value)
      return value.utc if value.is_a?(Time)
      return unless value.is_a?(String) && value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)

      Time.iso8601(value).utc
    rescue ArgumentError
      nil
    end
  end
end
