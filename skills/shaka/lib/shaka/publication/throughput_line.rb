# frozen_string_literal: true

require 'json'
require 'time'

module Shaka
  # Renders the spend after the model line, the intervals in Timings, and reads the check start that begins them.
  module ThroughputLine
    # The head-commit fields earliest_start reads. The description and the watcher share them so both
    # agree on when CI started.
    HEAD_CHECKS = 'oid status { contexts { createdAt } } ' \
                  'checkSuites(first: 100) { nodes { createdAt checkRuns(first: 100) { nodes { startedAt } } } }'
    SPEND = ' - AI spend: '
    INTERVALS = '**This head:** '

    def line(state) = "#{marker(state)}\n#{INTERVALS}#{intervals(state)}"

    # Appended to the model line.
    def header(state) = "#{SPEND}#{shown_spend(state)}"

    # Appended to the estimated cost line: task start to merge once merged, otherwise to ready;
    # nothing until that time is known.
    def took(state)
      ended, label = state['t3'] ? [state['t3'], 'merged'] : [state['t2'], 'ready']
      span = state['t0'] && ended && ended != 'UNKNOWN' ? interval(state['t0'], ended) : 'UNKNOWN'
      span == 'UNKNOWN' ? '' : " · #{label} in #{span}"
    end

    def earliest_start(commit)
      return unless commit.is_a?(Hash)

      starts = Array(commit.dig('checkSuites', 'nodes')).flat_map { |suite| suite_starts(suite) } +
               status_starts(commit['status'])
      starts.filter_map { |value| plausible_time(value) }.min
    end

    def prompt_stamp(commit) = earliest_start(commit)&.utc&.iso8601

    def keep_earlier(seen, carried, key, head)
      previous = carried['head'] == head ? carried[key] : nil
      kept = parse_time(previous) if previous.is_a?(String) && previous != 'UNKNOWN'
      earlier = kept && (seen == 'UNKNOWN' || kept <= parse_time(seen))
      earlier ? previous : seen
    end

    private

    def marker(state) = "<!-- shaka:stats #{JSON.generate(ordered(state))} -->"
    def ordered(state) = ThroughputStats::KEYS.filter_map { |key| [key, state[key]] if state.key?(key) }.to_h

    def intervals(state)
      "Prompt to CI #{prompt(state)} · CI to ready #{ci(state)} · Ready to merged #{merged(state)}"
    end

    def shown_spend(state) = spend_text?(state['spend']) ? state['spend'] : 'UNKNOWN'
    def spend_text?(text) = text.is_a?(String) && !text.strip.empty?

    def prompt(state)
      return 'UNKNOWN' if state['t0'].nil?
      return state['t3'].nil? ? 'pending' : 'UNKNOWN' if state['t1'].nil?

      interval(state['t0'], state['t1'])
    end

    # Once merged, a ready time nobody recorded can no longer arrive.
    def ci(state)
      if state['t2'].nil?
        state['t3'].nil? ? 'pending' : 'UNKNOWN'
      else
        ci_span(state)
      end
    end

    def ci_span(state) = state['t2'] == 'UNKNOWN' || state['t1'].nil? ? 'UNKNOWN' : interval(state['t1'], state['t2'])
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

    def status_starts(status)
      status.is_a?(Hash) ? Array(status['contexts']).filter_map { |row| row['createdAt'] if row.is_a?(Hash) } : []
    end

    def suite_starts(suite)
      return [] unless suite.is_a?(Hash)

      runs = Array(suite.dig('checkRuns', 'nodes')).filter_map { |run| run['startedAt'] if run.is_a?(Hash) }
      [suite['createdAt'], *runs]
    end

    def plausible_time(value) = (time = parse_time(value)) && time.year >= 2000 ? time : nil
  end
end
