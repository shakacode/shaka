# frozen_string_literal: true

# Measures the description prose the agent wrote, so the length limit leaves out the helper's own lines.

require_relative 'opening_prose'
require_relative 'visible_prose'

module Shaka
  # The visible text a description's author supplied, measured the way the rendered prose is: headings, tables,
  # quotes, code blocks, images, link addresses and collapsed details do not count, and an inline code span is one
  # word. It reads the content, not GitHub's rendering, so it gives the same count when GitHub refuses its renderer.
  # The publisher note is left out: Shaka's publisher attribution writes it.
  module SuppliedProse
    # A heading needs a space after its marks, so "#1336 fixes it" stays prose.
    HIDDEN_LINE = /\A {0,3}(?:>|\#{1,6}(?:[ \t]|$))/
    # Underlining a line with = or - makes it a heading.
    SETEXT = /^[^\n]*\S[^\n]*\n {0,3}(?:=+|-+)[ \t]*(?:\n|\z)/
    # Only a block with a delimiter row renders as a table; a lone line starting with a pipe is prose.
    TABLE_DELIMITER = /^ {0,3}\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/
    LIST_MARKER = /^ *(?:[-*+]|\d{1,9}[.)])[ \t]+/
    FENCE = /^ {0,3}(```|~~~).*?^ {0,3}\1[^\n]*$/m

    module_function

    def words(content) = VisibleProse.words(VisibleProse.new(markdown(content)).paragraphs.flatten.join(' '))

    # Each piece is its own paragraph, as it renders. Labels such as "Why:" are the helper's, so they stay out.
    def markdown(content)
      blocks = [content['summary'], *Array(content['sections']).map { object(it)['body'] }]
      [*blocks.map { block(it) if it.is_a?(String) }, *labeled(content).map { inline(it) if it.is_a?(String) }]
        .compact.join("\n\n")
    end

    # These render after a label or a list marker on one line, so a leading > or # there is ordinary text.
    def labeled(content)
      verification = OpeningProse.verification_lines(object(content['verification'])).map(&:last)
      [*Array(content['decisions']), object(content['checkpoint'])['next_action'],
       *intent(object(content['intent'])), *verification, object(content['risk_record'])['summary']]
    end

    def intent(spec)
      understanding = spec['task_understanding']
      [*OpeningProse::INTENT.keys.map { spec[it] },
       *(understanding.is_a?(Hash) ? understanding.values_at('goal', 'done_when') : [understanding]),
       *Array(spec['review_focus']).map { object(it)['reason'] }]
    end

    def object(value) = value.is_a?(Hash) ? value : {}

    # GitHub hides these in its rendering, so they are removed before counting.
    def block(text)
      blocks = text.gsub(FENCE, '').split(/\n[ \t]*\n/).reject { it.match?(TABLE_DELIMITER) && it.include?('|') }
      inline(blocks.map { it.gsub(SETEXT, '').lines.grep_v(HIDDEN_LINE).join.gsub(LIST_MARKER, '') }.join("\n\n"))
    end

    def inline(text)
      text.gsub(/!\[[^\]]*\]\([^)]*\)/, '').gsub(/(`+).+?\1/m, ' Code ')
          .gsub(/\]\([^)]*\)/, ']').gsub(/\]\[[^\]]*\]/, ']')
    end
  end
end
