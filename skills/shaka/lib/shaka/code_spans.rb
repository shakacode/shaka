# frozen_string_literal: true

require 'cgi'
require_relative 'error'

module Shaka
  # Refuses a description whose example GitHub shows without its backticks: three or more
  # backticks can delimit a code span, so ```js``` renders as js (PR #1331).
  module CodeSpans
    ADVICE = 'to show the backticks, wrap the example in a longer run, such as ```` ```js``` ````, ' \
             'or describe it in words'

    module_function

    # html is GitHub's rendering of source. Every copy of a candidate is counted on both sides, so a kept
    # copy cannot hide a lost one, and a copy must stand alone, so ```` ```` ```` cannot stand in for ```.
    # HTML comments render as nothing; each becomes a line break so the text around it cannot join.
    def check!(source, html)
      text = source.to_s.gsub(/<!--.*?-->/m, "\n")
      shown = visible(html)
      lost = candidates(text).uniq.find { |candidate| copies(shown, candidate) < copies(text, candidate) }
      raise Error, "GitHub renders #{lost} as inline code and drops its backticks; #{ADVICE}." if lost
    end

    def copies(text, candidate) = text.scan(/(?<!`)#{Regexp.escape(candidate)}(?!`)/).size

    def candidates(text) = text.each_line.flat_map { |line| bare_spans(line) }

    # Pairs backtick runs left to right, as GitHub does: a run closes at the next run of its length.
    # A pair of three or more with no run between is a candidate; fences, escapes, and longer
    # delimiters can match too, and GitHub's rendering decides whether the backticks survive.
    def bare_spans(line)
      pairs(line.enum_for(:scan, /`+/).map { Regexp.last_match }).filter_map do |open, close|
        line[open.begin(0)...close.end(0)] if open[0].size >= 3
      end
    end

    # Each pair with no run between it, as [open, close].
    def pairs(runs)
      found = []
      while (open = runs.shift)
        close = runs.index { |run| run[0] == open[0] }
        next unless close

        found << [open, runs[close]] if close.zero?
        runs = runs.drop(close + 1)
      end
      found
    end

    # Highlighting splits code into elements, so tags go before the comparison. The text is only compared, never output.
    def visible(html) = CGI.unescapeHTML(html.split(/<[^>]*>/).join)
  end
end
