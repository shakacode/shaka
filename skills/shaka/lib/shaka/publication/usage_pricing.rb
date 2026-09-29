# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Each report is priced once, when `shaka usage` runs, with the rate card of that moment.
  # Its note travels with its record, so a carried row still says which prices produced it.
  module UsagePricing
    # Kept as plain lines inside the comment: an escaped \n would read as a literal escape.
    HIDDEN = /^<!-- usage-note\n(.*?)\n-->$/m
    SUMMARY = 'How each estimate was priced'

    module_function

    def checked(value)
      return if value.nil?
      raise Error, 'Publication usage record note must be text.' unless value.is_a?(String)

      text = PublicationText.checked(value.strip, 'usage record note')
      raise Error, 'Publication usage record note must not close a comment.' if text.match?(/--!?>/)

      text.empty? ? nil : text
    end

    def hidden(note) = note && "<!-- usage-note\n#{note}\n-->"

    def from_block(block) = checked(block[HIDDEN, 1])

    # Takes [label, note] pairs, one per report, and lists each distinct note under the
    # reports it priced.
    def details(pairs)
      return if pairs.empty?

      priced = pairs.select { |_label, note| note }.group_by(&:last)
      parts = priced.map { |note, group| "**#{labels(group)}**\n\n#{note}" }
      missing = pairs.select { |_label, note| note.nil? }
      parts << "_No pricing note was recorded for #{labels(missing)}._" unless missing.empty?
      "<details>\n<summary>#{SUMMARY}</summary>\n\n#{parts.join("\n\n")}\n\n</details>"
    end

    def labels(group)
      names = group.map { |label, _note| label.tr('-', "\u2011") }
      names.tally.map { |label, count| count > 1 ? "#{label} ×#{count}" : label }.join(', ')
    end
  end
end
