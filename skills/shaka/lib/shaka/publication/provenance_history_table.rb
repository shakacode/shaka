# frozen_string_literal: true

module Shaka
  # Renders provenance history entries as a Markdown table, oldest first.
  module ProvenanceHistoryTable
    HEADINGS = ['Head', 'Shaka skill version', 'User-requested model / effort', 'Recommended model / effort',
                'Active model / effort'].freeze
    REASON_HEADING = 'Why the recommendation changed'
    KEY = %w[head recommended].freeze

    module_function

    # Each replan explains the next row, in order, whose recommendation changed to its value; its
    # column appears only when some row has a reason.
    def render(entries, routes, replans)
      reasons = reasons(entries, replans)
      headings = reasons.any? ? [*HEADINGS, REASON_HEADING] : HEADINGS
      rows = entries.zip(reasons).map { |entry, reason| row(cells(entry, routes, (reason.to_s if reasons.any?))) }
      [row(headings), "|#{' --- |' * headings.size}", *rows].join("\n")
    end

    def reasons(entries, replans)
      pending = replans.dup
      [nil] + entries.each_cons(2).map do |before, entry|
        next if before['recommended'] == entry['recommended']

        index = pending.index { |replan| same_change?(replan, entry) }
        pending.shift(index + 1).last['reason'] if index
      end
    end

    def same_change?(replan, entry) = replan.values_at(*KEY) == entry.values_at(*KEY)

    def cells(entry, routes, reason)
      ["`#{entry['head'][0, 7]}`", entry['workflow'], *entry.values_at(*routes), *reason]
    end

    def row(cells) = "| #{cells.join(' | ')} |"
  end
end
