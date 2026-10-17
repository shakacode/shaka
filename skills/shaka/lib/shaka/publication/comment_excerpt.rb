# frozen_string_literal: true

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
    # Three or more backticks or tildes open a fence; a backtick fence's info text has no backtick.
    FENCE = /\A(?<marker>`{3,}(?=[^`]*\z)|~{3,})/
    # Four spaces, or a tab after fewer, indent a code block.
    INDENTED = /\A(?: {4}| {0,3}\t)/

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

    # A link keeps its text. An unclosed fence hides the rest of the comment, as it does
    # when GitHub renders it; backticks later on the line make it a code span instead.
    # An indented line is code unless it continues a paragraph.
    def prose(body)
      fence = nil
      code_may_start = true
      body.to_s.gsub(/<!--.*?-->/m, ' ').gsub(LINK, '\\1').each_line.reject do |line|
        code, fence = code_line(line, fence, code_may_start)
        code_may_start = code || line.strip.empty?
        code || line.lstrip.start_with?('>')
      end.join(' ')
    end

    # Whether a line is code, and the fence open after it. Only a run of the same character at
    # least as long closes a fence, and a fence-shaped line in an indented block opens none.
    def code_line(line, fence, code_may_start)
      return [true, (fence unless line.strip.match?(/\A#{fence}#{fence[0]}*\z/))] if fence
      return [true, nil] if code_may_start && line.match?(INDENTED)

      fence = line.lstrip[FENCE, :marker]
      [!fence.nil?, fence]
    end

    # GitHub accepts a backslash before any ASCII punctuation. A backslash of the comment's own
    # becomes a look-alike, because the rendering check refuses `\n` as an unconverted line break.
    def escape(text)
      text.gsub(/[[:cntrl:]]/, ' ').tr('\\', '∖').gsub(PUNCTUATION) { |character| "\\#{character}" }
    end
  end
end
