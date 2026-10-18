# frozen_string_literal: true

require_relative 'comment_code_lines'

module Shaka
  # Repeats a short comment, or the opening of an agent's reply, so that nothing in it can change
  # the Markdown around it.
  module CommentExcerpt
    # A comment within both bounds is repeated whole. A longer one is already on the pull request,
    # so the list links a summary of it. The bounds also cap how much outside text is repeated.
    WORDS = 12
    LENGTH = 90
    SUMMARY_WORDS = 30
    # The four ranges of ASCII punctuation.
    PUNCTUATION = /[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]/
    LINK = /!?\[([^\]\n]*)\]\([^)\n]*\)/

    module_function

    # The whole comment in quotation marks; nil when it is too long to repeat or has no prose.
    def whole(body)
      text = prose(body).split.join(' ')
      "“#{escape(text)}”" unless text.empty? || text.split.size > WORDS || text.length > LENGTH
    end

    def prose?(body) = !prose(body).strip.empty?

    # The opening words of an agent's reply; nil when it holds only quoted text, code, or markers.
    def opening(body)
      words = prose(body).split
      return if words.empty?

      text = words.first(WORDS).join(' ')
      shown = text[0, LENGTH].rstrip
      "“#{escape(shown)}#{'…' if words.size > WORDS || shown.length < text.length}”"
    end

    # An agent's summary of a longer comment: one line, short enough to read in a table cell.
    def summary?(text)
      text.is_a?(String) && !text.strip.empty? && !text.match?(/[\r\n]/) && text.split.size <= SUMMARY_WORDS
    end

    # A link keeps its text. Code is left out as GitHub renders it: an unclosed fence hides the
    # rest of its list item or comment, and backticks later on the line make a code span instead.
    def prose(body)
      code = CodeLines.new
      body.to_s.gsub(/<!--.*?-->/m, ' ').gsub(LINK, '\\1').each_line.reject do |line|
        code.code?(line) || line.lstrip.start_with?('>')
      end.join(' ')
    end

    # GitHub accepts a backslash before any ASCII punctuation. A backslash of the comment's own
    # becomes a look-alike, because the rendering check refuses `\n` as an unconverted line break.
    def escape(text)
      text.gsub(/[[:cntrl:]]/, ' ').tr('\\', '∖').gsub(PUNCTUATION) { |character| "\\#{character}" }
    end
  end
end
