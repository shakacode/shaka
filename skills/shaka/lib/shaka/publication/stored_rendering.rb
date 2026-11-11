# frozen_string_literal: true

module Shaka
  # Reduces the HTML GitHub stores for a comment to what `POST /markdown` returns for the same text,
  # as far as the rendering checks read it. A stored comment is rendered with repository context,
  # so GitHub links commit SHAs, issue references, and mentions, and wraps code blocks and tables.
  module StoredRendering
    LINK = %r{<a\b[^>]*\bclass="[^"]*\b(?:commit-link|issue-link|user-mention|team-mention)\b[^"]*"[^>]*>(.*?)</a>}m
    SNIPPET = %r{<div\b[^>]*\bclass="snippet-clipboard-content\b[^>]*>(.*?)</div>}m
    TABLE = %r{</?markdown-accessiblity-table>}
    # Source text GitHub never links: comments, code, link targets, and HTML tags.
    UNLINKED = [/<!--.*?-->/m, /^~~~.*?^~~~/m, /```.*?```/m, /(`+)(?:(?!\1).)*\1(?!`)/m, /\]\([^)\s]*\)/,
                /<[^>]*>/].freeze

    module_function

    def normalize(html, source)
      tokens = UNLINKED.reduce(source) { |text, pattern| text.gsub(pattern, ' ') }.scan(/\b\h{7,40}\b/)
      html.gsub(' dir="auto"', '').gsub(SNIPPET, '\1').gsub(TABLE, '').gsub(LINK) do
        link, text = Regexp.last_match.captures.unshift(Regexp.last_match(0))
        sha = link[%r{/commit/(\h{40})}, 1]
        sha ? written_sha(sha, tokens) : text.gsub(/<[^>]+>/, '')
      end
    end

    # GitHub shows a linked SHA abbreviated; the checks expect the SHA as the source wrote it,
    # which is the next unlinked-text token it starts with.
    def written_sha(sha, tokens)
      index = tokens.index { |token| sha.start_with?(token.downcase) }
      index ? tokens.slice!(0..index).last : sha
    end
  end
end
