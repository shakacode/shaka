# frozen_string_literal: true

require_relative 'error'
require_relative 'graphql_refusal'
require_relative 'required_checks'

module Shaka
  # Reads one PR head together with the required checks observed for it.
  class Status
    # rest_fallback reads over REST when GitHub refuses GraphQL; only `shaka pr` asks for it.
    def initialize(github, seam_required_checks: nil, rest_fallback: false)
      @github = github
      @seam_required_checks = seam_required_checks
      @rest_fallback = rest_fallback
    end

    def call
      read(@github)
    rescue GraphqlRefused
      raise unless @rest_fallback

      read(@github.over_rest)
    end

    private

    def read(reader)
      head = reader.snapshot['headRefOid']
      checks = required_checks(reader)
      current = reader.snapshot
      raise Error, 'PR head changed while reading status; retry.' unless current['headRefOid'] == head

      current.merge(checks)
    end

    # A repository without required checks is a valid state for reading, not a failure.
    def required_checks(reader)
      gate = RequiredChecks.new(reader, seam_names: @seam_required_checks).call
      { 'requiredChecks' => gate.fetch('checks'), 'requiredChecksSource' => gate.fetch('source') }
    rescue Error => e
      { 'requiredChecks' => nil, 'requiredChecksUnavailable' => e.message }
    end
  end
end
