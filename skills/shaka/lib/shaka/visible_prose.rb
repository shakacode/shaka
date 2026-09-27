# frozen_string_literal: true

# Reduces rendered Markdown to the prose a reader sees without expanding anything.

module Shaka
  # Splits visible Markdown into paragraphs and list items, each as its sentences.
  class VisibleProse
    # Tables, headings, block quotes, and comments are not running prose.
    HIDDEN_LINE = /\A[ \t]*(?:\||\#{1,6}(?:[ \t]|$)|>|<!--)/
    LIST_ITEM = /\n(?=[ \t]*(?:[-*+]|\d+[.)])[ \t])/
    LIST_MARKER = /\A[ \t]*(?:[-*+]|\d+[.)])[ \t]+/
    CODE_SPAN = /(`+)(?:(?!\1).)*\1(?!`)/m
    # Closing quotes, brackets, and emphasis may follow the stop; opening ones may precede the capital.
    SENTENCE_END = /(?<=[.!?])[*_"')\]]*\s+(?=[*_"'(\[]*[[:upper:][:digit:]])/

    def self.words(text) = text.split.count { |token| token.match?(/[[:alnum:]]/) }

    def initialize(markdown)
      @fence = nil
      @depth = 0
      @lines = markdown.to_s.lines.map { |line| visible?(line) ? line : "\n" }
    end

    def paragraphs
      @lines.join.split(/\n[ \t]*\n/).flat_map { |block| block.split(LIST_ITEM) }
            .map { |unit| inline_text(unit).split(SENTENCE_END) }
            .reject(&:empty?)
    end

    private

    def visible?(line)
      return false if fenced?(line) || collapsed?(line)

      !line.match?(HIDDEN_LINE)
    end

    def fenced?(line)
      marker = line[/\A[ \t]*(`{3,}|~{3,})/, 1]
      if @fence
        @fence = nil if marker && marker[0] == @fence[0] && marker.size >= @fence.size
        return true
      end
      @fence = marker
      !marker.nil?
    end

    # A details block is read only by someone who chooses to open it.
    def collapsed?(line)
      tags = line.gsub(CODE_SPAN, '')
      @depth += tags.scan(/<details\b/i).size
      hidden = @depth.positive?
      @depth = [@depth - tags.scan(%r{</details\s*>}i).size, 0].max
      hidden
    end

    # Code spans and URLs read as one capitalized word, so a sentence may still start with one.
    def inline_text(unit)
      unit.gsub(/!\[[^\]]*\]\([^)]*\)/, '')
          .gsub(/\[([^\]]*)\]\((?:<[^>]*>|[^)]*)\)/, '\1')
          .gsub(CODE_SPAN, 'Code')
          .gsub(%r{https?://\S+}, 'Link')
          .gsub(/<[^>]*>/, ' ')
          .sub(LIST_MARKER, '')
          .gsub(/\s+/, ' ').strip
    end
  end
end
