# frozen_string_literal: true

require 'cgi'

module Shaka
  # Reduces the HTML GitHub stores for a comment to what `POST /markdown` returns for the same text,
  # as far as the rendering checks read it. A stored comment is rendered with repository context,
  # so GitHub links commit SHAs, issue references, and mentions, and marks text direction.
  module StoredRendering
    LINK = %r{<a\b[^>]*\bclass="[^"]*\b(?:commit-link|issue-link|user-mention|team-mention)\b[^"]*"[^>]*>(.*?)</a>}m
    # Source text GitHub never links: comments, code, link targets, and HTML tags.
    UNLINKED = [/<!--.*?-->/m, /^~~~.*?^~~~/m, /```.*?```/m, /(`+)(?:(?!\1).)*\1(?!`)/m, /\]\([^)\s]*\)/,
                /<[^>]*>/].freeze

    module_function

    def normalize(html, source)
      text = UNLINKED.reduce(source) { |rest, pattern| rest.gsub(pattern, ' ') }
      cursor = 0
      html.gsub(' dir="auto"', '').gsub(LINK) do
        match = Regexp.last_match
        sha = match[0][%r{/commit/(\h{40})}, 1]
        next match[1].split(/<[^>]+>/).join unless sha # the link's text, read for checks, never rendered

        written, cursor = written_sha(sha, CGI.unescapeHTML(match.pre_match[/[^>]{0,24}\z/]), text, cursor)
        written
      end
    end

    # GitHub shows a linked SHA abbreviated; the checks expect the SHA as the source wrote it. The text
    # just before the link finds that spot in the source, and the full SHA stands in when it cannot.
    def written_sha(sha, before, text, cursor)
      position = cursor
      while (found = text.match(/#{Regexp.escape(before)}(\h{7,40})\b/, position))
        return [found[1], found.end(0)] if sha.start_with?(found[1].downcase)

        position = found.begin(0) + 1
      end
      [sha, cursor]
    end
  end
end
