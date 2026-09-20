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
      GENERATED = /\A(?:\u{1F916}|\#{1,6}[ \t])/

      module_function

      # Code, HTML, link targets and bare URLs are not sentences the writer composed,
      # and two summaries citing the same commit would otherwise look like copied prose.
      # The identity line and the headings are the helper's own words, identical in every
      # pair it renders, so counting them would report copying that nobody wrote.
      def text(markdown)
        bare = PublicationText.prose(markdown.to_s).gsub(LINK, '\1').gsub(TAG, ' ').gsub(URL, ' ')
        bare.lines.grep_v(GENERATED).join
      end

      # Unicode-aware, so accented and Cyrillic prose is compared rather than skipped.
      # A script written without spaces, such as Chinese or Japanese, yields too few
      # tokens to form an eight-word run, so this check does not reach it.
      def words(markdown) = text(markdown).downcase.scan(WORD)

      def shingles(markdown, size)
        words(markdown).each_cons(size).to_set { |run| run.join(' ') }
      end
    end
  end
end
