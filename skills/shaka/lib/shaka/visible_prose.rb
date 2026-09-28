# frozen_string_literal: true

# Reduces GitHub's rendered HTML to the prose a reader sees without expanding anything.

require 'cgi'

module Shaka
  # Splits rendered HTML into paragraphs and list items, each as its sentences.
  class VisibleProse
    # Content inside these is hidden, except in an open details block and a collapsed block's summary.
    CONTAINER = %r{\A<(/?)(details|summary|pre|table|h[1-6]|blockquote)\b([^>]*)>}i
    BLOCK = %r{\A</?(?:p|li|ul|ol|div|hr)\b}i
    CODE = %r{\A<(/?)code\b}i
    # A false split only shortens a sentence, so any word may start the next one, as in "iOS".
    SENTENCE_END = /(?<=[.!?])["')\]]*\s+(?=["'(\[]*[[:alnum:]])/

    def self.words(text) = text.split.count { |token| token.match?(/[[:alnum:]]/) }

    def initialize(html)
      @stack = []
      @summary = false
      @code = false
      @text = html.to_s.split(/(<[^>]*>)/).map { |token| token.start_with?('<') ? tag(token) : text(token) }.join
    end

    def paragraphs
      @text.split("\n\n").map { |block| block.gsub(/\s+/, ' ').strip.split(SENTENCE_END) }.reject(&:empty?)
    end

    private

    def visible? = @summary || @stack.all?(:shown)

    def text(token)
      visible? && !@code ? CGI.unescapeHTML(token).gsub(/\s+/, ' ') : ''
    end

    # A hard line break or inline tag keeps its sentence and paragraph together.
    def tag(token)
      match = token.match(CONTAINER)
      return container(*match.captures) if match
      return code(token.match(CODE)[1].empty?) if token.match?(CODE)

      token.match?(BLOCK) ? "\n\n" : ' '
    end

    def container(closing, name, attributes)
      if name.casecmp?('summary')
        @summary = closing.empty? && @stack.last == :collapsed && @stack[0...-1].all?(:shown)
      elsif closing.empty?
        @stack.push(state(name, attributes))
      else
        @stack.pop
      end
      "\n\n"
    end

    def state(name, attributes)
      return :hidden unless name.casecmp?('details')

      attributes.match?(/\bopen\b/i) ? :shown : :collapsed
    end

    # An inline code span reads as one capitalized word, so a sentence may still start with one.
    def code(opening)
      @code = opening
      opening && visible? ? ' Code ' : ''
    end
  end
end
