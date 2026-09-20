# frozen_string_literal: true

require_relative '../publication'

module Shaka
  module Writing
    # Reduces published Markdown to the prose a style check is allowed to read.
    module Prose
      TAG = /<[^>]+>/
      LINK = /\[([^\]]*)\]\([^)]*\)/
      URL = %r{https?://\S+}
      WORD = /[[:alnum:]']+/
      IDENTITY = /\A\u{1F916}/
      HEADING = /\A\#{1,6}[ \t]/
      FENCE = /\A(?<mark>`{3,}|~{3,})[^`~]*$/

      module_function

      # Code, HTML, link targets and bare URLs are not sentences the writer composed,
      # and two summaries citing the same commit would otherwise look like copied prose.
      # Indented code is left in: separating it from an indented paragraph inside a list
      # needs a Markdown parser, and dropping every indented line would exempt real prose.
      # The leading identity line and the headings are labels rather than sentences, and
      # every pair the helper renders repeats them, so counting them would report copying
      # that nobody wrote. Copied headings go uncounted as a result; a shared label is not
      # the copied resolution the rule is about.
      def text(markdown)
        bare = PublicationText.prose(unfenced(markdown.to_s)).gsub(LINK, '\1').gsub(TAG, ' ').gsub(URL, ' ')
        lines = bare.lines
        lines.shift if lines.first&.match?(IDENTITY)
        lines.grep_v(HEADING).join
      end

      # Unicode-aware, so accented and Cyrillic prose is compared rather than skipped.
      # A script written without spaces, such as Chinese or Japanese, yields too few
      # tokens to form an eight-word run, so this check does not reach it.
      # GitHub closes a fence only with a delimiter at least as long as the one that opened
      # it, and renders a fence left open as code to the end of the body. The shared stripper
      # does neither, so fenced regions come out here before it looks for code spans.
      def unfenced(markdown)
        open_mark = nil
        markdown.lines.reject do |line|
          mark = line[FENCE, :mark]
          open_mark = fence_state(open_mark, mark)
          !open_mark.nil? || !mark.nil?
        end.join
      end

      def fence_state(open_mark, mark)
        return open_mark if mark.nil?
        return mark if open_mark.nil?

        mark.length >= open_mark.length ? nil : open_mark
      end

      def words(markdown) = text(markdown).downcase.scan(WORD)

      def shingles(markdown, size)
        words(markdown).each_cons(size).to_set { |run| run.join(' ') }
      end
    end
  end
end
