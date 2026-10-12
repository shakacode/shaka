# frozen_string_literal: true

module Shaka
  # Quotes the opening of a comment so that nothing in it can change the Markdown around it.
  module CommentExcerpt
    WORDS = 12
    LENGTH = 90
    # The four ranges of ASCII punctuation.
    PUNCTUATION = /[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]/
    LINK = /!?\[([^\]\n]*)\]\([^)\n]*\)/

    module_function

    # nil when the comment holds only quoted text, code, or hidden markers.
    def quote(body)
      words = prose(body).split
      return if words.empty?

      text = words.first(WORDS).join(' ')
      shown = text[0, LENGTH].rstrip
      "“#{escape(shown)}#{'…' if words.size > WORDS || shown.length < text.length}”"
    end

    # A link keeps its text. An unclosed fence hides the rest of the comment, as it does
    # when GitHub renders it.
    def prose(body)
      fenced = false
      body.to_s.gsub(/<!--.*?-->/m, ' ').gsub(LINK, '\\1').each_line.reject do |line|
        fence = line.lstrip.start_with?('```', '~~~')
        fenced = !fenced if fence
        fence || fenced || line.lstrip.start_with?('>')
      end.join(' ')
    end

    # GitHub accepts a backslash before any ASCII punctuation. A backslash of the comment's own
    # becomes a look-alike, because the rendering check refuses `\n` as an unconverted line break.
    def escape(text)
      text.gsub(/[[:cntrl:]]/, ' ').tr('\\', '∖').gsub(PUNCTUATION) { |character| "\\#{character}" }
    end
  end
end
