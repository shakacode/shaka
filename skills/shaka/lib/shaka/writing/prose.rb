# frozen_string_literal: true

require_relative '../publication'

module Shaka
  module Writing
    # Reduces published Markdown to the prose a style check is allowed to read.
    module Prose
      TAG = /<[^>]+>/
      LINK = /\[([^\]]*)\]\([^)]*\)/
      URL = %r{https?://\S+}
      WORD = /[a-z0-9']+/

      module_function

      # Code, HTML, link targets and bare URLs are not sentences the writer composed,
      # and two summaries citing the same commit would otherwise look like copied prose.
      def text(markdown)
        PublicationText.prose(markdown.to_s).gsub(LINK, '\1').gsub(TAG, ' ').gsub(URL, ' ')
      end

      def words(markdown) = text(markdown).downcase.scan(WORD)

      def shingles(markdown, size)
        words(markdown).each_cons(size).to_set { |run| run.join(' ') }
      end
    end
  end
end
