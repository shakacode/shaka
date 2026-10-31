# frozen_string_literal: true

require 'time'
require_relative 'run_summary'
require_relative 'time_zone'
require_relative 'timeline_steps'

module Shaka
  # Renders the totals and rows for a pull request's measured steps. Once the bars show when each step
  # ran, only the steps a reader must act on keep a row, and the rest stay in the hidden marker.
  class MeasuredSteps
    LEGEND = 'Each measured step is a helper run recorded on the machine that ran it. A step ' \
             'logged on a machine that never updated this description is missing, so the totals ' \
             'can be partial. A step can overlap the stretches above.'
    FAILED_HEADING = '**Failed or unfinished steps:**'
    MAX_ROWS = 30

    def initialize(zone)
      @zone = zone
    end

    def parts(steps, dropped, charted:)
      return [] if steps.empty?

      listed = charted ? steps.reject { |step| step['exit'].zero? } : steps
      [totals(steps), (settings(steps) if charted), (FAILED_HEADING if charted && listed.any?), table(listed),
       omitted(steps.size, listed.size, dropped, charted), LEGEND]
    end

    private

    def totals(steps)
      groups = steps.group_by { |step| TimelineSteps::NAMES.fetch(step['command']) }
      parts = groups.map do |name, group|
        runs = group.size == 1 ? '1 run' : "#{group.size} runs"
        "#{name} #{RunSummary.duration(group.sum { |step| step['duration_ms'] })} (#{runs})"
      end
      "**Measured steps:** #{parts.join(' · ')}"
    end

    def settings(steps)
      models = steps.map { |step| model(step) }.uniq - ['—']
      machines = steps.map { |step| step['machine'] || 'UNKNOWN' }.uniq
      [("**Models:** #{models.join('; ')}" if models.any?), "**Machines:** #{machines.join(', ')}"].compact.join(' · ')
    end

    def table(steps)
      return if steps.empty?

      lines = ['| Step | Started | Time | Result | Model | Machine |', '| --- | --- | ---: | --- | --- | --- |']
      lines.concat(steps.last(MAX_ROWS).map { |step| "| #{cells(step).join(' | ')} |" })
      lines.join("\n")
    end

    def omitted(kept, listed, dropped, charted)
      notes = []
      kind = charted ? 'failed or unfinished steps' : 'steps'
      notes << "Showing the latest #{MAX_ROWS} of #{listed} #{kind}." if listed > MAX_ROWS
      notes << "The totals cover the latest #{kept}; #{dropped} older steps are no longer kept." if dropped.positive?
      notes.join(' ') unless notes.empty?
    end

    def cells(step)
      [name(step), TimeZone.strftime(Time.iso8601(step['at']), @zone, '%Y-%m-%d %H:%M'),
       RunSummary.duration(step['duration_ms']), result(step), model(step), step['machine'] || 'UNKNOWN']
    end

    # A review or checkpoint exits 0 whatever it concluded, so its exit says only whether it finished.
    def result(step)
      exit = step['exit']
      return (exit.zero? ? 'passed' : "failed (exit #{exit})") if step['command'] == 'evidence run'

      exit.zero? ? 'completed' : "not completed (exit #{exit})"
    end

    def name(step) = [TimelineSteps::NAMES.fetch(step['command']), step['check']].compact.join(': ')

    def model(step)
      model = step.values_at('provider', 'model', 'effort').compact.join(' · ')
      model.empty? ? '—' : model
    end
  end
end
