# frozen_string_literal: true

require 'time'
require_relative '../error'

module Shaka
  # Narrows a shared native session to responses after the current task began.
  module UsageSinceTime
    private

    def select_since_time
      cutoff = Time.iso8601(@options[:since_time])
      @selected_responses.select! do |_id, record|
        response_time(record) > cutoff
      end
    rescue ArgumentError
      raise Error, '--since-time needs an ISO 8601 timestamp with a timezone.'
    end

    def response_time(record)
      timestamp = record['timestamp']
      return Time.iso8601(timestamp) if timestamp.is_a?(String) && timestamp.match?(UsageOptions::ISO_TIME)

      raise Error, '--since-time needs a zoned timestamp for every response.'
    rescue ArgumentError
      raise Error, '--since-time needs a zoned timestamp for every response.'
    end
  end
end
