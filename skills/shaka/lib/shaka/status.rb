# frozen_string_literal: true

require_relative 'base_checks'
require_relative 'error'
require_relative 'graphql_refusal'
require_relative 'required_checks'

module Shaka
  # Reads one PR head together with the required checks observed for it.
  class Status
    # rest_fallback reads over REST when GitHub refuses GraphQL, and base_checks adds BaseChecks's
    # report; only `shaka pr` asks for them.
    def initialize(github, seam_required_checks: nil, rest_fallback: false, base_checks: false)
      @github = github
      @seam_required_checks = seam_required_checks
      @rest_fallback = rest_fallback
      @base_checks = base_checks
    end

    def call
      read(@github)
    rescue GraphqlRefused
      raise unless @rest_fallback

      read(@github.over_rest)
    end

    private

    # Every head read sits between the two snapshots, so a head that moves meanwhile is refused
    # rather than paired with another commit's checks.
    def read(reader)
      first = reader.snapshot
      checks = required_checks(reader)
      compared = base_checks(reader, first['baseRefName'], checks) if @base_checks
      current = reader.snapshot
      raise Error, 'PR head changed while reading status; retry.' unless current['headRefOid'] == first['headRefOid']

      current.merge(checks, compared || {})
    end

    # Like required checks, an unreadable base comparison is reported rather than failing the read.
    def base_checks(reader, base_ref, checks)
      required = checks['requiredChecks']&.map { |check| check['name'] }
      BaseChecks.new(@github).call(base_ref, reader.checks, required)
    rescue Error => e
      { 'baseChecksUnavailable' => e.message }
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
