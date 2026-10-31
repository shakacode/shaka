# frozen_string_literal: true

module Shaka
  # Maps times to columns, replacing each cut with a fixed gap so a long wait cannot flatten the rest.
  class TimingAxis
    WIDTH = 52
    CUT_CELLS = 8
    # A cut takes about a seventh of the width, so a shorter idle wait would gain little from one.
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

    # The time at a column's left edge, or nil inside a cut, which has no time of its own.
    def time_at(target)
      return if @cuts.any? { |from, _to| target > column(from) && target <= column(from) + CUT_CELLS }

      passed = @cuts.select { |from, _to| column(from) < target }
      @start + (target * @per_cell) + passed.sum { |from, to| to - from - (CUT_CELLS * @per_cell) }
    end

    private

    def chosen(idle, total)
      long = idle.select { |from, to| to - from > total * CUT_SHARE }
      # A wait that fills the whole timeline leaves nothing to scale, so it stays uncut.
      long.sum { |from, to| to - from } < total ? long.sort : []
    end

    def removed(time) = @cuts.sum { |from, to| time > from ? [time, to].min - from : 0 }
  end
end
