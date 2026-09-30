# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Renders the work a PR needs outside its merge, such as a secret to set or a backfill to run.
  module StepsBesidesMerging
    KEY = 'steps_besides_merging'
    HEADING = 'Steps besides merging'
    MARKER = '<!-- shaka:steps-besides-merging -->'
    TIMES = ['before merge', 'after merge'].freeze
    COLUMNS = { 'when' => 'When', 'step' => 'Step', 'who' => 'Who', 'where' => 'Where',
                'verify' => 'How to verify' }.freeze

    module_function

    # Required so a description cannot skip the check; `none` records that nothing was found.
    def render(content)
      refuse_heading(content['sections'])
      steps = content[KEY]
      return [] if steps == 'none'

      unless steps.is_a?(Array) && !steps.empty?
        raise Error, "Publication #{KEY} must be none or a nonempty list of steps."
      end

      rows = steps.map { |step| row(step) }
      ["#{MARKER}\n## #{HEADING}\n\n#{[line(COLUMNS.values), line(['---'] * COLUMNS.size), *rows].join("\n")}"]
    end

    def row(step)
      raise Error, "Publication #{KEY} items must be objects." unless step.is_a?(Hash)

      cells = COLUMNS.keys.map { |field| PublicationText.single_line(step[field], "#{KEY} #{field}") }
      unless TIMES.include?(cells.first)
        raise Error, "Publication #{KEY} when must be #{TIMES.map { |time| "`#{time}`" }.join(' or ')}."
      end

      line(cells)
    end

    def line(cells) = "| #{cells.map { |cell| PublicationText.table_cell(cell) }.join(' | ')} |"

    def refuse_heading(sections)
      return unless sections.is_a?(Array)
      return unless sections.any? { |section| section.is_a?(Hash) && section['heading'].to_s.strip.casecmp?(HEADING) }

      raise Error, "Publication #{HEADING} must be supplied as the #{KEY} list, not a section."
    end

    private_class_method :row, :line, :refuse_heading
  end
end
