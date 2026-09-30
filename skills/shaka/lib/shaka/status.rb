# frozen_string_literal: true

require_relative 'error'
require_relative 'required_checks'

module Shaka
  # Reads one PR head together with the required checks observed for it.
  class Status
    def initialize(github, seam_required_checks: nil)
      @github = github
      @seam_required_checks = seam_required_checks
    end

    def call
      pull = @github.snapshot
      head = pull['headRefOid']
      checks = required_checks
      names = @github.workflow_configuration(pull)
      current = @github.snapshot
      raise Error, 'PR head changed while reading status; retry.' unless current['headRefOid'] == head

      current.merge(checks).merge('workflowNames' => names)
    end

    private

    # A repository without required checks is a valid state for reading, not a failure.
    def required_checks
      gate = RequiredChecks.new(@github, seam_names: @seam_required_checks).call
      { 'requiredChecks' => gate.fetch('checks'), 'requiredChecksSource' => gate.fetch('source') }
    rescue Error => e
      { 'requiredChecks' => nil, 'requiredChecksUnavailable' => e.message }
    end
  end
end
