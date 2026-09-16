# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Reads one PR head together with the required checks observed for it.
  class Status
    def initialize(github)
      @github = github
    end

    def call
      head = @github.snapshot['headRefOid']
      checks = required_checks
      current = @github.snapshot
      raise Error, 'PR head changed while reading status; retry.' unless current['headRefOid'] == head

      current.merge(checks)
    end

    private

    # A repository without required checks is a valid state for reading, not a failure.
    def required_checks
      { 'requiredChecks' => @github.required_checks }
    rescue Error => e
      { 'requiredChecks' => nil, 'requiredChecksUnavailable' => e.message }
    end
  end
end
