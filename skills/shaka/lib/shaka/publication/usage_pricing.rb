# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Each report is priced once, when `shaka usage` runs, with the rate card of that moment.
  # Its note, with that rate card and the report's coverage gaps, travels with its record,
  # so a carried row still says which prices produced it and what it left out.
  module UsagePricing
    # Kept as plain lines inside the comment: an escaped \n would read as a literal escape.
    HIDDEN = /^<!-- usage-note\n(.*?)\n-->$/m
    SUMMARY = 'How each report was measured and priced'
    # Only known generated paragraphs are shortened. Unknown notes remain evidence.
    ACCOUNTING = {
      'Cached input is part of input; reasoning output is part of output.' => nil,
      'Anthropic input excludes cached input and cache writes; reasoning output is part of output.' => nil,
      'Input excludes cache reads and writes; native total sums input, output, reasoning, and cache.' => nil,
      'Input excludes cache reads and writes; reasoning output is part of output. ' \
      'Recorded native cost is nominal, not an actual charge.' =>
        'Recorded native cost is nominal, not an actual charge.',
      'Cached input and cache writes are part of input; reasoning output and native total are UNKNOWN. ' \
      'Parent-agent turn only; subagents excluded.' => 'Reasoning output and native total are UNKNOWN. ' \
                                                       'Parent-agent turn only; subagents excluded.'
    }.freeze
    ANTHROPIC_EXPLANATION = 'Uncached input, cache reads and cache writes are separate charges, and a 1-hour ' \
                            'cache write costs more than a 5-minute one. Standard-speed responses are priced; ' \
                            'fast mode is priced for Opus models with a published rate.'
    ANTHROPIC_PARAGRAPH = Regexp.new('\\A(Anthropic API list prices, verified \\d{4}-\\d{2}-\\d{2}\\.) ' \
                                     "#{Regexp.escape(ANTHROPIC_EXPLANATION)}\\z")

    module_function

    def checked(value)
      return if value.nil?
      raise Error, 'Publication usage record note must be text.' unless value.is_a?(String)

      text = PublicationText.checked(value.strip, 'usage record note')
      raise Error, 'Publication usage record note must not close a comment.' if text.match?(/--!?>/)
      # Kept raw in the hidden record, a tag here would fail the carry shape check and drop the report.
      raise Error, 'Publication usage record note must not contain < or >.' if text.match?(/[<>]/)

      text.empty? ? nil : text
    end

    def hidden(note) = note && "<!-- usage-note\n#{note}\n-->"

    def from_block(block) = checked(block[HIDDEN, 1])

    # Takes [label, note] pairs, one per report, and lists each distinct note under the
    # reports it priced.
    def details(pairs)
      return if pairs.empty?

      priced = pairs.select { |_label, note| note }.group_by(&:last)
      parts = priced.map { |note, group| "**#{labels(group)}**\n\n#{concise(note)}" }
      missing = pairs.select { |_label, note| note.nil? }
      parts << "_No note was recorded for #{labels(missing)}._" unless missing.empty?
      "<details>\n<summary>#{SUMMARY}</summary>\n\n#{parts.join("\n\n")}\n\n</details>"
    end

    # Full notes stay in hidden records and are carried without rewriting or repricing.
    def concise(note)
      note.split(/\n\n+/).filter_map do |paragraph|
        if ACCOUNTING.key?(paragraph)
          ACCOUNTING[paragraph]
        else
          paragraph.sub(ANTHROPIC_PARAGRAPH, '\\1')
        end
      end.join("\n\n")
    end

    # A report name keeps its hyphens from breaking the line; a note keeps real hyphens for its URLs.
    def visible(label) = label.tr('-', "\u2011")

    def labels(group)
      names = group.map { |label, _note| visible(label) }
      names.tally.map { |label, count| count > 1 ? "#{label} ×#{count}" : label }.join(', ')
    end
  end
end
