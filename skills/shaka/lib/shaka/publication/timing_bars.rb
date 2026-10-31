# frozen_string_literal: true

require 'time'
require_relative 'run_summary'
require_relative 'time_zone'
require_relative 'timing_axis'
require_relative 'timing_stretches'

module Shaka
  # Draws a pull request's stretches and measured steps as text lanes on one time axis. The bars are
  # plain ASCII in a code block, so they cost few tokens to read and look the same in every theme.
  class TimingBars
    WIDTH = TimingAxis::WIDTH
    # Room for a lane's total, such as `1h 29m`, between its name and its bars.
    TOTAL_WIDTH = 8
    TICK_EVERY = 13
    KEY = '- before the PR  = PR open  . waiting on a person  # step  x failed'
    CUT_KEY = '  // idle wait cut'
    STRETCH_GLYPHS = { TimingStretches::BEFORE => '-' }.freeze
    LANE_NAMES = { 'evidence run' => 'Validation', 'review run' => 'Review',
                   'post-implementation run' => 'Checkpoint' }.freeze

    def initialize(rows, steps, zone)
      @rows = rows
      @steps = steps
      @zone = zone
    end

    # Returns nil when there is no span of time to draw.
    def render
      first, last = (@rows + spans).flat_map { |span| span.values_at(:from, :to) }.minmax
      return unless first && last > first

      axis = TimingAxis.new(first, last, idle_waits)
      ['```text', header(first, last), ruler(axis), *lanes(axis), '', key(axis), '```'].join("\n")
    end

    private

    def spans
      @spans ||= @steps.map do |step|
        from = Time.iso8601(step['at'])
        { lane: lane(step), order: LANE_NAMES.keys.index(step['command']), from:,
          to: from + (step['duration_ms'] / 1000.0), failed: !step['exit'].zero? }
      end
    end

    def lane(step)
      name = LANE_NAMES.fetch(step['command'])
      step['command'] == 'review run' ? [name, step['provider']].compact.join(' ') : name
    end

    # Only time with no step running can be cut, so the axis never hides work.
    def idle_waits
      @rows.select { |row| row[:wait] }.flat_map do |row|
        spans.reduce([[row[:from], row[:to]]]) { |gaps, span| gaps.flat_map { |gap| outside(gap, span) } }
      end
    end

    def outside((from, to), span)
      return [[from, to]] if span[:to] <= from || span[:from] >= to

      [[from, span[:from]], [span[:to], to]].select { |start, finish| finish > start }
    end

    def lanes(axis)
      pr = @rows.empty? ? [] : [['PR', pr_total, pr_cells(axis)]]
      steps = lane_names.map { |name| [name, step_total(name), step_cells(axis, name)] }
      (pr + steps).map { |name, total, cells| "#{name.ljust(pad)}#{total.rjust(TOTAL_WIDTH)}  #{cells.join}".rstrip }
    end

    def lane_names = spans.sort_by { |span| [span[:order], span[:lane]] }.map { |span| span[:lane] }.uniq

    def pad = @pad ||= ['PR', *spans.map { |span| span[:lane] }].map(&:size).max

    def pr_total = RunSummary.duration((@rows.map { |row| row[:to] }.max - @rows.map { |row| row[:from] }.min) * 1000)

    def step_total(name)
      RunSummary.duration(spans.select { |span| span[:lane] == name }.sum { |span| span[:to] - span[:from] } * 1000)
    end

    # Waits draw last, so a one-minute wait stays visible beside a day of other work.
    def pr_cells(axis)
      cells = Array.new(WIDTH, ' ')
      @rows.sort_by { |row| row[:wait] ? 1 : 0 }.each { |row| paint(cells, axis, row, pr_glyph(row)) }
      mark_cuts(cells, axis) { |from, to| "//#{length(to - from)}//" }
    end

    def pr_glyph(row) = row[:wait] ? '.' : STRETCH_GLYPHS.fetch(row[:name], '=')

    # Runs draw in time order, so a shared cell shows the later one: a retry that passed does not read failed.
    def step_cells(axis, name)
      cells = Array.new(WIDTH, ' ')
      mine = spans.select { |span| span[:lane] == name }
      mine.sort_by { |span| span[:from] }.each do |span|
        part_from_previous(cells, axis.column(span[:from]))
        paint(cells, axis, span, span[:failed] ? 'x' : '#')
      end
      mark_cuts(cells, axis) { '//' }
    end

    # A blank cell keeps back-to-back runs apart, unless the earlier run has only that one cell.
    def part_from_previous(cells, start)
      cells[start - 1] = ' ' if start > 1 && cells[start - 1] != ' ' && cells[start - 2] != ' '
    end

    def paint(cells, axis, span, glyph)
      (axis.column(span[:from])..axis.column(span[:to])).each { |column| cells[column] = glyph }
    end

    # The mark starts one cell into the gap, so a step ending right at the cut keeps its own cell.
    def mark_cuts(cells, axis)
      axis.cuts.each do |from, to|
        yield(from, to)[0, TimingAxis::CUT_CELLS - 1].each_char.with_index(axis.column(from) + 1) do |char, column|
          cells[column] = char
        end
      end
      cells
    end

    def length(seconds)
      minutes = (seconds / 60).floor
      return "#{minutes}m" if minutes < 60

      hours = minutes / 60
      hours < 100 ? "#{hours}h" : "#{hours / 24}d"
    end

    def header(first, last)
      span = RunSummary.duration((last - first) * 1000)
      "#{clock(first, '%m-%d %H:%M')} to #{clock(last, '%m-%d %H:%M %Z')} (#{span})"
    end

    # Clock times along the axis, so a reader need not work out when a run happened.
    def ruler(axis)
      line = ' ' * WIDTH
      (0...WIDTH).step(TICK_EVERY).each do |column|
        time = axis.time_at(column)
        line[column, 5] = clock(time, '%H:%M') if time && column + 5 <= WIDTH
      end
      "#{' ' * (pad + TOTAL_WIDTH + 2)}#{line}".rstrip
    end

    def clock(time, pattern) = TimeZone.strftime(time, @zone, pattern)

    def key(axis) = axis.cuts.empty? ? KEY : "#{KEY}#{CUT_KEY}"
  end
end
