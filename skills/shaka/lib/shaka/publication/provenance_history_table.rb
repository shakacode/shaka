# frozen_string_literal: true

module Shaka
  # Renders provenance history entries as a Markdown table, oldest first.
  module ProvenanceHistoryTable
    HEADINGS = ['Head', 'Shaka skill version', 'User-requested model / effort', 'Recommended model / effort',
                'Active model / effort'].freeze
    REASON_HEADING = 'Why the recommendation changed'

    module_function

    # reasons maps [head, recommended] to the reason a recommendation changed; its column
    # appears only when some entry has one.
    def render(entries, routes, reasons)
      column = entries.any? { |entry| reason(reasons, entry) }
      headings = column ? [*HEADINGS, REASON_HEADING] : HEADINGS
      rows = entries.map { |entry| row(cells(entry, routes, (reason(reasons, entry).to_s if column))) }
      [row(headings), "|#{' --- |' * headings.size}", *rows].join("\n")
    end

    def reason(reasons, entry) = reasons[[entry['head'], entry['recommended']]]

    def cells(entry, routes, reason)
      ["`#{entry['head'][0, 7]}`", entry['workflow'], *entry.values_at(*routes), *reason]
    end

    def row(cells) = "| #{cells.join(' | ')} |"
  end
end
