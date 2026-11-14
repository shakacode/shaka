# frozen_string_literal: true

module Shaka
  # Validation phases as name-to-milliseconds maps: the shape a validation command may report and a
  # description may carry. A result file or description body is editable, so every reader passes its
  # phases through `sanitize` again.
  module Phases
    NAME = /\A[a-z][a-z0-9_-]{0,23}\z/
    MAX_PHASES = 8
    # Thirty days; a larger value is not a measurement and could overflow the duration renderer.
    MAX_MS = 30 * 24 * 3_600_000

    module_function

    # Phase names with their total milliseconds, in first-reported order: {"tests" => 250000}. A
    # phase reported twice is summed.
    def sanitize(phases)
      pairs = phases.is_a?(Hash) ? phases.to_a : Array(phases)
      pairs.each_with_object({}) do |(name, duration), totals|
        next unless shaped?(name, duration) && (totals.key?(name) || totals.size < MAX_PHASES)

        sum = totals.fetch(name, 0) + duration
        totals[name] = sum if sum <= MAX_MS
      end
    end

    def shaped?(name, duration)
      name.is_a?(String) && NAME.match?(name) && duration.is_a?(Integer) && duration.between?(0, MAX_MS)
    end

    # Adds several runs' phases together. The phase cap applies to each run, not to the sum, so a name
    # only a later run reported is kept.
    def combine(list)
      list.each_with_object({}) do |phases, totals|
        sanitize(phases).each { |name, value| totals[name] = totals.fetch(name, 0) + value }
      end
    end

    # "tests 4m 10s · rubocop 1m 2s", from phases already passed through `sanitize` or `combine`.
    def summary(phases, duration)
      phases.map { |name, milliseconds| "#{name} #{duration.call(milliseconds)}" }.join(' · ')
    end
  end
end
