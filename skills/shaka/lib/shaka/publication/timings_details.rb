# frozen_string_literal: true

require_relative '../error'
require_relative 'run_summary'
require_relative 'timeline_steps'
require_relative 'timing_stretches'

module Shaka
  # Renders the time between checkpoints, how long each checkpoint waited on a person, and the
  # measured steps, such as validation runs, that the pull request's sessions recorded.
  class TimingsDetails
    SUMMARY = 'Timings'
    UNAVAILABLE = 'GitHub did not supply the timeline; the next update tries again.'
    OPEN = ['still waiting', 'this update'].freeze
    GUIDE = '[Understand the timings](https://shaka.shakacode.com/docs/reference/timings).'
    LEGEND = 'Times are UTC wall-clock time. A wait runs from when an attention label goes on until it ' \
             'comes off or the pull request merges or closes.'
    STEPS_LEGEND = 'Each measured step is a helper run recorded on the machine that ran it; a step ' \
                   'can overlap the stretches above.'
    # Thirty rows keep the body far below GitHub's size limit however often a pull request waits.
    MAX_ROWS = 30

    def self.refuse_free_form!(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.match?(/\Atimings\b/i) }

      raise Error, 'Publication timings are read from the pull request timeline, not supplied as a details item.'
    end

    def self.for(timeline) = timeline ? [new(timeline).detail] : []

    def initialize(timeline, now: Time.now.utc)
      @timeline = timeline
      @now = now.utc
    end

    def detail
      steps = Array(@timeline['steps'])
      # The reason can quote gh output, so it stays out of the public body.
      unavailable = @timeline.key?('unavailable')
      parts = unavailable ? [UNAVAILABLE] : stretches
      parts.concat(measured(steps)) unless steps.empty?
      parts << GUIDE unless unavailable
      # The hidden line lets the next update, from any session, keep these steps.
      parts << TimelineSteps.hidden(steps) unless steps.empty?
      # A collapsed summary counts as visible description prose, so the totals stay inside.
      { 'summary' => SUMMARY, 'body' => parts.compact.join("\n\n") }
    end

    private

    def stretches
      rows = TimingStretches.new(@timeline, @now).rows
      [totals(rows), table(rows.last(MAX_ROWS)), omitted(rows), LEGEND]
    end

    def measured(steps)
      shown = steps.last(MAX_ROWS)
      lines = ['| Step | Started | Time | Result | Model | Machine |', '| --- | --- | ---: | --- | --- | --- |']
      lines.concat(shown.map { |step| "| #{step_cells(step).join(' | ')} |" })
      [step_totals(steps), lines.join("\n"), STEPS_LEGEND]
    end

    def step_totals(steps)
      groups = steps.group_by { |step| TimelineSteps::NAMES.fetch(step['command']) }
      parts = groups.map do |name, group|
        runs = group.size == 1 ? '1 run' : "#{group.size} runs"
        "#{name} #{RunSummary.duration(group.sum { |step| step['duration_ms'] })} (#{runs})"
      end
      "**Measured steps:** #{parts.join(' · ')}"
    end

    def step_cells(step)
      [step_name(step), clock(Time.iso8601(step['at'])), RunSummary.duration(step['duration_ms']),
       step['exit'].zero? ? 'passed' : "failed (exit #{step['exit']})", step_model(step), step['machine'] || 'UNKNOWN']
    end

    def step_name(step) = [TimelineSteps::NAMES.fetch(step['command']), step['check']].compact.join(': ')

    def step_model(step)
      model = step.values_at('provider', 'model', 'effort').compact.join(' · ')
      model.empty? ? '—' : model
    end

    def totals(rows)
      waited = rows.select { |row| row[:wait] }
      parts = ["#{duration(total(rows.reject { |row| row[:wait] }))} between checkpoints"]
      parts << "#{duration(total(waited))} waiting on a person in #{count(waited.size)}" unless waited.empty?
      "**Totals:** #{parts.join(' · ')}"
    end

    def omitted(rows)
      return if rows.size <= MAX_ROWS

      "Showing the latest #{MAX_ROWS} of #{rows.size} stretches; the totals include all of them."
    end

    def count(waits) = waits == 1 ? '1 wait' : "#{waits} waits"
    def total(rows) = rows.sum { |row| row[:to] - row[:from] }

    def table(rows)
      lines = ['| Stretch | From | To | Time |', '| --- | --- | --- | ---: |']
      lines.concat(rows.map { |row| "| #{[row[:name], clock(row[:from]), to_cell(row), length(row)].join(' | ')} |" })
      lines.join("\n")
    end

    def to_cell(row) = row[:ending] ? "#{clock(row[:to])} (#{row[:ending]})" : clock(row[:to])
    # A stretch still running when this update rendered keeps growing until the next one.
    def length(row) = "#{duration(row[:to] - row[:from])}#{' so far' if OPEN.include?(row[:ending])}"
    def clock(time) = time.strftime('%Y-%m-%d %H:%M')

    def duration(seconds)
      minutes = (seconds / 60).floor
      return '<1m' if minutes < 1
      return "#{minutes}m" if minutes < 60

      hours, minutes = minutes.divmod(60)
      return "#{hours}h #{minutes}m" if hours < 24

      days, hours = hours.divmod(24)
      "#{days}d #{hours}h"
    end
  end
end
