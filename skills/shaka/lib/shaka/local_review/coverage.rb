# frozen_string_literal: true

module Shaka
  # Recognizes the requested Coverage section and the older bold paragraph format.
  # Mask fenced examples for boundary matching, then return the original source bytes.
  class LocalReviewCoverage
    SECTION = /^\#{2} (?i:Coverage)[^\n]*\n(.*?)(?=^\#{1,2} |^REVIEWED [a-f0-9]{40} BY |\z)/m
    PARAGRAPH = /^\*\*(?i:Coverage):\*\*[ \t]*(.*?)(?=\n\s*\n|^REVIEWED [a-f0-9]{40} BY |\z)/m
    FENCE = /^ {0,3}(`{3,}|~{3,})([^\n]*)$/

    def initialize(report) = @report = report

    def text
      # HTML can surround a heading or span its boundary; decline ambiguous reports.
      return if @report.include?('<')

      @fence = nil
      masked = @report.lines.map { |line| mask(line) }.join
      match = masked.match(SECTION) || masked.match(PARAGRAPH)
      return unless match

      excerpt = @report[match.begin(1)...match.end(1)].strip
      excerpt unless excerpt.empty?
    end

    private

    def mask(line)
      marker = line.match(FENCE)
      if @fence
        @fence = nil if closing?(marker)
      elsif marker
        @fence = marker[1]
      else
        return line
      end
      # Hide blank lines inside a fence too; retain the closing newline as a prose boundary.
      line.gsub(@fence ? /./m : /[^\r\n]/, 'x')
    end

    def closing?(marker)
      marker && marker[1][0] == @fence[0] && marker[1].size >= @fence.size && marker[2].strip.empty?
    end
  end
end
