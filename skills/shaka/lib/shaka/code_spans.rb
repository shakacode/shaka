# frozen_string_literal: true

require 'cgi'
require_relative 'error'

module Shaka
  # Refuses a description whose example GitHub shows without its backticks: three or more
  # backticks can delimit a code span, so ```js``` renders as js (PR #1331).
  module CodeSpans
    # Equal runs with no backtick between. Fences, escapes, and longer delimiters also match;
    # GitHub's rendering decides whether the backticks survive.
    CANDIDATE = /(?<!`)(`{3,})(?!`)[^`\n]+(?<!`)\1(?!`)/
    ADVICE = 'to show the backticks, wrap the example in a longer run, such as ```` ```js``` ````, ' \
             'or describe it in words'

    module_function

    # html is GitHub's rendering of source. Each occurrence is counted, so a kept copy cannot hide a lost
    # one, and a copy must stand alone, so ```` ```` ```` text cannot stand in for ```.
    # HTML comments render as nothing, so examples inside them are not counted.
    def check!(source, html)
      written = candidates(source).tally
      return if written.empty?

      shown = visible(html)
      lost = written.find { |candidate, count| shown.scan(/(?<!`)#{Regexp.escape(candidate)}(?!`)/).size < count }
      raise Error, "GitHub renders #{lost.first} as inline code and drops its backticks; #{ADVICE}." if lost
    end

    # A removed comment becomes a line break, so the text around it cannot join into a candidate.
    def candidates(source)
      source.gsub(/<!--.*?-->/m, "\n")
            .to_enum(:scan, CANDIDATE).map { Regexp.last_match[0] }
    end

    # Highlighting splits code into elements, so tags go before the comparison. The text is only compared, never output.
    def visible(html) = CGI.unescapeHTML(html.split(/<[^>]*>/).join)
  end
end
