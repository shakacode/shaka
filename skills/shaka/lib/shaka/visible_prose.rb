# frozen_string_literal: true

# Reduces GitHub's rendered HTML to the prose a reader sees without expanding anything.

require 'cgi'

module Shaka
  # Splits rendered HTML into paragraphs and list items, each as its sentences.
  class VisibleProse
    # Collapsed details, code blocks, tables, headings, and quotes are not running prose.
    HIDDEN = %r{\A<(/?)(?:details|pre|table|h[1-6]|blockquote)\b}i
    BLOCK = %r{\A</?(?:p|li|ul|ol|div|br|hr)\b}i
    CODE = %r{\A<(/?)code\b}i
    # A false split only shortens a sentence, so any word may start the next one, as in "iOS".
    SENTENCE_END = /(?<=[.!?])["')\]]*\s+(?=["'(\[]*[[:alnum:]])/

    def self.words(text) = text.split.count { |token| token.match?(/[[:alnum:]]/) }

    def initialize(html)
      @hidden = 0
      @code = false
      @text = html.to_s.split(/(<[^>]*>)/).map { |token| token.start_with?('<') ? tag(token) : text(token) }.join
    end

    def paragraphs
      @text.split("\n\n").map { |block| block.gsub(/\s+/, ' ').strip.split(SENTENCE_END) }.reject(&:empty?)
    end

    private

    def text(token)
      @hidden.zero? && !@code ? CGI.unescapeHTML(token).gsub(/\s+/, ' ') : ''
    end

    def tag(token)
      if (hidden = token.match(HIDDEN))
        @hidden = [@hidden + (hidden[1].empty? ? 1 : -1), 0].max
        return "\n\n"
      end
      return code(token.match(CODE)[1].empty?) if token.match?(CODE)

      token.match?(BLOCK) ? "\n\n" : ''
    end

    # An inline code span reads as one capitalized word, so a sentence may still start with one.
    def code(opening)
      @code = opening
      opening && @hidden.zero? ? ' Code ' : ''
    end
  end
end
