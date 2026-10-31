# frozen_string_literal: true

require_relative '../error'
require_relative 'measured_steps'
require_relative 'timeline_steps'
require_relative 'timing_bars'
require_relative 'timing_stretches'
require_relative 'task_timing'
require_relative 'time_zone'

module Shaka
  # Renders the time between checkpoints, how long each checkpoint waited on a person, and the
  # measured steps, such as validation runs, that the pull request's sessions recorded.
  class TimingsDetails
    SUMMARY = 'Timings'
    UNAVAILABLE = 'GitHub did not supply the timeline; the next update tries again.'
    OPEN = ['still waiting', 'this update'].freeze
    GUIDE = '[Understand the timings](https://shaka.shakacode.com/docs/reference/timings).'
    LEGEND = 'Times are %s wall-clock time. A wait runs from when an attention label goes on until it ' \
             'comes off or the pull request merges or closes.'
    MAX_ROWS = MeasuredSteps::MAX_ROWS

    def self.refuse_free_form!(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.match?(/\Atimings\b/i) }

      raise Error, 'Publication timings are read from the pull request timeline, not supplied as a details item.'
    end

    def self.for(timeline, time_zone = nil) = timeline ? [new(timeline, time_zone:).detail] : []

    def initialize(timeline, now: Time.now.utc, time_zone: nil)
      @timeline = timeline
      @now = now.utc
      @zone = TimeZone.renderable(time_zone)
    end

    def detail
      steps = Array(@timeline['steps'])
      dropped = @timeline.fetch('dropped_steps', 0)
      # The hidden line lets the next update, from any session, keep these steps.
      parts = [*visible(steps, dropped), TimelineSteps.hidden(steps, dropped), TaskTiming.hidden(@timeline)]
      { 'summary' => summary, 'body' => parts.compact.join("\n\n") }
    end

    private

    def visible(steps, dropped)
      # The reason can quote gh output, so it stays out of the public body.
      unavailable = @timeline.key?('unavailable')
      chart = bars(steps, unavailable)
      [*(unavailable ? [UNAVAILABLE, chart] : stretches(chart)), TaskTiming.summary(@timeline, @zone),
       *MeasuredSteps.new(@zone).parts(steps, dropped, charted: !chart.nil?), (GUIDE unless unavailable)]
    end

    def summary = "#{SUMMARY} · #{@timeline.key?('unavailable') ? 'timeline unavailable' : totals(timing_rows)}"

    def timing_rows = @timing_rows ||= TimingStretches.new(@timeline, @now).rows

    def stretches(chart)
      rows = timing_rows
      ["**Totals:** #{totals(rows)}", chart, table(rows.last(MAX_ROWS)), omitted(rows), format(LEGEND, @zone)]
    end

    # The bars are a convenience, so any failure to draw them leaves the full tables in place.
    def bars(steps, unavailable)
      draw_bars(unavailable ? [] : timing_rows, steps)
    rescue StandardError
      nil
    end

    def draw_bars(rows, steps) = TimingBars.new(rows, steps, @zone).render

    def totals(rows)
      waited = rows.select { |row| row[:wait] }
      parts = ["#{duration(total(rows.reject { |row| row[:wait] }))} between checkpoints"]
      parts << "#{duration(total(waited))} waiting on a person in #{count(waited.size)}" unless waited.empty?
      parts.join(' · ')
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
    def clock(time) = TimeZone.strftime(time, @zone, '%Y-%m-%d %H:%M')

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
