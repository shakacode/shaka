# frozen_string_literal: true

require_relative '../error'
require_relative '../usage/usage_records'
require_relative 'text'

module Shaka
  # A hand-written table can claim anything, so only a report `shaka usage` marked counts (#256).
  # `description` also checks the supplied details before carrying, since a carried report would pass.
  module UsageDetails
    TABLE_SEPARATOR = /\A\s*\|[\s|:-]*-{3}[\s|:-]*\|\s*\z/

    module_function

    def require_rendered(items)
      bodies = Array(items).filter_map do |item|
        item['body'] if item.is_a?(Hash) && item['summary'].to_s.match?(/usage/i)
      end
      return if bodies.any? { |body| rendered_reports(body.to_s).any? { |report| complete_table?(report) } }

      raise Error, 'Publication description requires usage details rendered by `shaka usage`; ' \
                   'run `shaka usage --commit SHA --contribution NAME` and supply its output unchanged ' \
                   'as the usage details body. A hand-written usage table is refused.'
    end

    # Only a marked report whose identity parses counts; its table must sit between the markers.
    def rendered_reports(body)
      body.to_enum(:scan, UsageRecords::BLOCK).filter_map { Regexp.last_match[0] }
          .select { |report| UsageRecords.text_records(report).any? }
    end

    def complete_table?(body)
      PublicationText.prose(body).lines.map(&:rstrip).each_cons(3).any? do |header, separator, data|
        pipe_row?(header) && separator.match?(TABLE_SEPARATOR) && pipe_row?(data) && !data.match?(TABLE_SEPARATOR)
      end
    end

    def pipe_row?(line) = line.match?(/\A\s*\|.+\|\s*\z/)
  end
end
