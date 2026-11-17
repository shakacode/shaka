# frozen_string_literal: true

module Shaka
  # Renders provenance history entries as a Markdown table, oldest first.
  module ProvenanceHistoryTable
    HEADINGS = ['Head', 'Shaka skill version', 'User-requested model / effort', 'Recommended model / effort',
                'Active model / effort'].freeze
    REASON_HEADING = 'Why the recommendation changed'

    module_function

    # reasons holds one value per row; the column appears only when some row has a reason.
    def render(entries, routes, reasons)
      column = reasons.any?
      headings = column ? [*HEADINGS, REASON_HEADING] : HEADINGS
      rows = entries.each_with_index.map { |entry, index| row(cells(entry, routes, (reasons[index].to_s if column))) }
      [row(headings), "|#{' --- |' * headings.size}", *rows].join("\n")
    end

    def cells(entry, routes, reason)
      ["`#{entry['head'][0, 7]}`", entry['workflow'], *entry.values_at(*routes), *reason]
    end

    def row(cells) = "| #{cells.join(' | ')} |"
  end
end
