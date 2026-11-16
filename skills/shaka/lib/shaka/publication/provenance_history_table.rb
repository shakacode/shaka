# frozen_string_literal: true

module Shaka
  # Renders provenance history entries as a Markdown table, oldest first.
  module ProvenanceHistoryTable
    HEADINGS = ['Head', 'Shaka skill version', 'User-requested model / effort', 'Recommended model / effort',
                'Active model / effort'].freeze
    REASON_HEADING = 'Why the recommendation changed'

    module_function

    # The reason column appears only once some entry replaced the recommendation.
    def render(entries, routes, reason)
      reasons = entries.any? { |entry| entry.key?(reason) }
      headings = HEADINGS + (reasons ? [REASON_HEADING] : [])
      rows = entries.map do |entry|
        cells = ["`#{entry['head'][0, 7]}`", entry['workflow'], *entry.values_at(*routes)]
        row(reasons ? cells << entry.fetch(reason, '') : cells)
      end
      [row(headings), "|#{' --- |' * headings.size}", *rows].join("\n")
    end

    def row(cells) = "| #{cells.join(' | ')} |"
  end
end
