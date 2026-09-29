# frozen_string_literal: true

require 'time'
require_relative '../error'

module Shaka
  # Narrows a shared native session to responses after the current task began.
  module UsageSinceTime
    private

    def select_since_time
      cutoff = Time.iso8601(@options[:since_time])
      @source.responses.select! do |_id, record|
        timestamp = record['timestamp']
        raise Error, '--since-time needs a timestamp for every response.' unless timestamp.is_a?(String)

        Time.iso8601(timestamp) > cutoff
      rescue ArgumentError
        raise Error, '--since-time needs a timestamp for every response.'
      end
    rescue ArgumentError
      raise Error, '--since-time needs an ISO 8601 timestamp with a timezone.'
    end
  end
end
