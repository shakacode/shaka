# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Checks supplied text for the mechanical failures models reproduce by hand.
  module PublicationText
    ESCAPE = /\\[nrt]/
    IDENTITY_FIELDS = %w[agent provider model effort].freeze

    module_function

    def required(value, field)
      raise Error, "Publication #{field} must be nonempty text." unless value.is_a?(String) && !value.strip.empty?

      checked(value, field)
    end

    # Fenced blocks and code spans hold intentional examples; only prose is checked.
    def prose(text)
      text.gsub(/^~~~.*?^~~~/m, '').gsub(/```.*?```/m, '').gsub(/(`+)(?:(?!\1).)*\1(?!`)/m, '')
    end

    # A summary is interpolated into raw HTML, so it must not be able to close its own tag.
    def summary_text(value, field)
      single_line(value, field).gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def list(value, field)
      return [] if value.nil?
      raise Error, "Publication #{field} must be a list." unless value.is_a?(Array)

      value
    end

    def single_line(value, field)
      text = required(value, field)
      raise Error, "Publication #{field} must be a single line." if text.match?(/[\r\n]/)

      text
    end

    # A collapsed Usage and cost summary that omits the USD cells hides the total behind a click.
    def usage_cost_summary(summary, body)
      return summary unless summary.match?(/usage/i)

      totals = usd_estimate_cells(body).map { |cell| summary_text(cell, 'usage cost cell') }
      leftover = unmatched_cost_cells(summary, totals)
      return summary if leftover.empty?

      "#{summary} · #{leftover.join(' · ')}"
    end

    def unmatched_cost_cells(summary, totals)
      tokens = summary.split(' · ')
      totals.reject do |cell|
        index = tokens.index(cell)
        next false unless index

        tokens.delete_at(index)
        true
      end
    end

    # Each carried usage record keeps its own estimate; the summary lists them and adds no total.
    def usd_estimate_cells(body)
      lines = body.each_line.map(&:rstrip).grep(/\A\s*\|\s*USD estimate\s*\|/)
      lines.flat_map do |line|
        line.strip.delete_prefix('|').delete_suffix('|').split('|').map(&:strip).drop(1).reject(&:empty?)
      end
    end

    def checked(value, field)
      return value unless prose(value).match?(ESCAPE)

      raise Error, "Publication #{field} contains a literal escape sequence; supply real line breaks."
    end

    def identity(value)
      raise Error, 'Publication identity must be supplied.' unless value.is_a?(Hash)

      fields = IDENTITY_FIELDS.map do |field|
        text = value[field]
        text.is_a?(String) && !text.strip.empty? ? single_line(text.strip, "identity #{field}") : 'UNKNOWN'
      end
      "🤖 #{fields.join(' · ')}"
    end
  end
end
