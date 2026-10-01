# frozen_string_literal: true

require_relative 'error'
require_relative 'required_checks'

module Shaka
  # Reads one PR head together with the required checks observed for it.
  class Status
    # `workflow_names: false` is for a caller, such as the watcher, that decides nothing from them.
    def initialize(github, seam_required_checks: nil, workflow_names: true)
      @github = github
      @seam_required_checks = seam_required_checks
      @workflow_names = workflow_names
    end

    def call
      pull = @github.snapshot
      head = pull['headRefOid']
      found = required_checks.merge(workflow_names(pull))
      current = @github.snapshot
      raise Error, 'PR head changed while reading status; retry.' unless current['headRefOid'] == head

      current.merge(found)
    end

    private

    def workflow_names(pull)
      @workflow_names ? { 'workflowNames' => @github.workflow_configuration(pull) } : {}
    end

    # A repository without required checks is a valid state for reading, not a failure.
    def required_checks
      gate = RequiredChecks.new(@github, seam_names: @seam_required_checks).call
      { 'requiredChecks' => gate.fetch('checks'), 'requiredChecksSource' => gate.fetch('source') }
    rescue Error => e
      { 'requiredChecks' => nil, 'requiredChecksUnavailable' => e.message }
    end
  end
end
