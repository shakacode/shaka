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
      FENCE = /\A(?:```|~~~)/

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
        bare = PublicationText.prose(closed(markdown.to_s)).gsub(LINK, '\1').gsub(TAG, ' ').gsub(URL, ' ')
        lines = bare.lines
        lines.shift if lines.first&.match?(IDENTITY)
        lines.grep_v(HEADING).join
      end

      # Unicode-aware, so accented and Cyrillic prose is compared rather than skipped.
      # A script written without spaces, such as Chinese or Japanese, yields too few
      # tokens to form an eight-word run, so this check does not reach it.
      # GitHub renders an unclosed fence as code to the end of the body, and the shared
      # stripper only removes a fence that closes, so an odd marker out takes the rest with it.
      def closed(markdown)
        lines = markdown.lines
        fences = lines.each_index.select { |index| lines[index].match?(FENCE) }
        fences.size.odd? ? lines[0...fences.last].join : markdown
      end

      def words(markdown) = text(markdown).downcase.scan(WORD)

      def shingles(markdown, size)
        words(markdown).each_cons(size).to_set { |run| run.join(' ') }
      end
    end
  end
end
