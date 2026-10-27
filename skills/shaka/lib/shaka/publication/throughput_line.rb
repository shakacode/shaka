# frozen_string_literal: true

require 'json'
require 'time'

module Shaka
  # Renders the throughput line and reads the check start that begins it.
  module ThroughputLine
    def line(state) = "#{marker(state)}\n#{visible(state)}"

    def earliest_start(commit)
      return unless commit.is_a?(Hash)

      starts = Array(commit.dig('checkSuites', 'nodes')).flat_map { |suite| suite_starts(suite) }
      starts.filter_map { |value| plausible_time(value) }.min
    end

    def prompt_stamp(commit)
      return unless commit.is_a?(Hash)

      start = earliest_start(commit)
      return start.utc.iso8601 if start

      pushed = commit['pushedDate']
      pushed if pushed.is_a?(String) && parse_time(pushed)
    end

    def keep_earlier(seen, carried, key, head)
      previous = carried['head'] == head ? carried[key] : nil
      earlier = previous.is_a?(String) && previous != 'UNKNOWN' && (seen == 'UNKNOWN' || previous <= seen)
      earlier ? previous : seen
    end

    private

    def marker(state) = "<!-- shaka:stats #{JSON.generate(ordered(state))} -->"
    def ordered(state) = ThroughputStats::KEYS.filter_map { |key| [key, state[key]] if state.key?(key) }.to_h

    def visible(state)
      "AI spend #{shown_spend(state)} · Prompt to CI #{prompt(state)} · " \
        "CI to ready #{ci(state)} · Ready to merged #{merged(state)}"
    end

    def shown_spend(state) = spend_text?(state['spend']) ? state['spend'] : 'UNKNOWN'
    def spend_text?(text) = text.is_a?(String) && !text.strip.empty?
    def prompt(state) = state['t0'].nil? || state['t1'].nil? ? 'UNKNOWN' : interval(state['t0'], state['t1'])
    def ci(state) = state['t2'].nil? ? 'pending' : "#{ci_span(state)} (#{round_label(state['rounds'])})"
    def ci_span(state) = state['t2'] == 'UNKNOWN' ? 'UNKNOWN' : interval(anchor(state), state['t2'])
    def anchor(state) = state['first_push'] || state['t1']
    def round_label(rounds) = positive_rounds?(rounds) ? "#{rounds} #{round_noun(rounds)}" : 'UNKNOWN rounds'
    def round_noun(rounds) = rounds == 1 ? 'round' : 'rounds'
    def positive_rounds?(rounds) = rounds.is_a?(Integer) && rounds.positive?
    def merged(state) = state['t3'].nil? ? 'pending' : merge_span(state)
    def merge_span(state) = unknown_merge?(state) ? 'UNKNOWN' : interval(state['t2'], state['t3'])
    def unknown_merge?(state) = state['t2'].nil? || state['t2'] == 'UNKNOWN' || state['t3'] == 'UNKNOWN'
    def interval(from, to) = ordered_times?(from, to) ? duration(parse_time(to) - parse_time(from)) : 'UNKNOWN'

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

    def stamp(value) = parse_time(value) && (value.is_a?(Time) ? value.utc.iso8601 : value)

    def parse_time(value)
      return value.utc if value.is_a?(Time)
      return unless value.is_a?(String) && value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)

      Time.iso8601(value).utc
    rescue ArgumentError
      nil
    end

    def suite_starts(suite)
      return [] unless suite.is_a?(Hash)

      runs = Array(suite.dig('checkRuns', 'nodes')).filter_map { |run| run['startedAt'] if run.is_a?(Hash) }
      [suite['createdAt'], *runs]
    end

    def plausible_time(value) = (time = parse_time(value)) && time.year >= 2000 ? time : nil
  end
end
