# frozen_string_literal: true

require 'time'
require_relative 'time_zone'

module Shaka
  # Draws a pull request's stretches and measured steps as text lanes on one time axis. The bars are
  # plain ASCII in a code block, so they cost few tokens to read and look the same in every theme.
  class TimingBars
    WIDTH = 60
    KEY = '= between checkpoints  . waiting on a person  # step  x failed'
    CUT_KEY = '  // idle wait cut'
    LANE_ORDER = { 'evidence run' => 0, 'review run' => 1, 'post-implementation run' => 2 }.freeze
    LANE_NAMES = { 'evidence run' => 'Validation', 'review run' => 'Review',
                   'post-implementation run' => 'Checkpoint' }.freeze

    # Maps a time to a column, replacing each cut with a fixed gap so a long wait cannot flatten the rest.
    class Axis
      CUT_CELLS = 8
      # A cut takes about an eighth of the width, so a shorter idle wait would gain nothing from one.
      CUT_SHARE = 0.25

      attr_reader :cuts

      def initialize(start, finish, idle)
        @start = start
        @cuts = chosen(idle, finish - start)
        kept = finish - start - removed(finish)
        @per_cell = kept / (WIDTH - (@cuts.size * CUT_CELLS))
      end

      def column(time)
        passed = @cuts.count { |from, _to| time > from }
        (((time - @start - removed(time)) / @per_cell).floor + (passed * CUT_CELLS)).clamp(0, WIDTH - 1)
      end

      private

      def chosen(idle, total)
        long = idle.select { |from, to| to - from > total * CUT_SHARE }
        # A wait that fills the whole timeline leaves nothing to scale, so it stays uncut.
        long.sum { |from, to| to - from } < total ? long.sort : []
      end

      def removed(time) = @cuts.sum { |from, to| time > from ? [time, to].min - from : 0 }
    end

    def initialize(rows, steps, zone)
      @rows = rows
      @steps = steps
      @zone = zone
    end

    # Returns nil when there is no span of time to draw.
    def render
      first, last = (@rows + spans).flat_map { |span| span.values_at(:from, :to) }.minmax
      return unless first && last > first

      axis = Axis.new(first, last, idle_waits)
      ['```text', header(first, last), *lanes(axis), '', key(axis), '```'].join("\n")
    end

    private

    def spans
      @spans ||= @steps.map do |step|
        from = Time.iso8601(step['at'])
        { lane: lane(step), order: LANE_ORDER.fetch(step['command']), from:,
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
      pr = @rows.empty? ? [] : [['PR', pr_cells(axis)]]
      steps = lane_names.map { |name| [name, step_cells(axis, name)] }
      (pr + steps).map { |name, cells| "#{name.ljust(pad)}#{cells.join}".rstrip }
    end

    def lane_names = spans.sort_by { |span| [span[:order], span[:lane]] }.map { |span| span[:lane] }.uniq

    def pad = @pad ||= (['PR', *spans.map { |span| span[:lane] }].map(&:size).max + 2)

    # Waits draw last, so a one-minute wait stays visible beside a day of other work.
    def pr_cells(axis)
      cells = Array.new(WIDTH, ' ')
      @rows.sort_by { |row| row[:wait] ? 1 : 0 }.each { |row| paint(cells, axis, row, row[:wait] ? '.' : '=') }
      mark_cuts(cells, axis) { |from, to| "//#{length(to - from)}//" }
    end

    # Runs draw in time order, so a shared cell shows the later one: a retry that passed does not read failed.
    def step_cells(axis, name)
      cells = Array.new(WIDTH, ' ')
      mine = spans.select { |span| span[:lane] == name }
      mine.sort_by { |span| span[:from] }.each { |span| paint(cells, axis, span, span[:failed] ? 'x' : '#') }
      mark_cuts(cells, axis) { '//' }
    end

    def paint(cells, axis, span, glyph)
      (axis.column(span[:from])..axis.column(span[:to])).each { |column| cells[column] = glyph }
    end

    # The mark starts one cell into the gap, so a step ending right at the cut keeps its own cell.
    def mark_cuts(cells, axis)
      axis.cuts.each do |from, to|
        yield(from, to)[0, Axis::CUT_CELLS - 1].each_char.with_index(axis.column(from) + 1) do |char, column|
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
      finish = TimeZone.strftime(last, @zone, '%m-%d %H:%M %Z')
      "#{' ' * pad}#{TimeZone.strftime(first, @zone, '%m-%d %H:%M').ljust(WIDTH - finish.size)}#{finish}"
    end

    def key(axis) = axis.cuts.empty? ? KEY : "#{KEY}#{CUT_KEY}"
  end
end
