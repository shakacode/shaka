# frozen_string_literal: true

module Shaka
  # An actionable failure at the workflow boundary.
  class Error < StandardError
    attr_reader :http_status

    def initialize(message, http_status: nil)
      @http_status = http_status
      super(message)
    end

    def self.from_gh(message, stderr)
      new(message, http_status: http_status_in(stderr))
    end

    def self.http_status_in(stderr)
      stderr[/\(HTTP (\d{3})\)/, 1]&.to_i
    end
  end
end
