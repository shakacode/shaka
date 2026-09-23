# frozen_string_literal: true

require_relative '../reviewer_selection'

module Shaka
  # Classifies a host-produced report without claiming the CLI was launched.
  class LocalReviewReportCheck
    def initialize(options) = @options = options

    def run
      head = @options[:head]
      raise Shaka::Error, '--head must be a full commit SHA' unless head.to_s.match?(LocalReview::SHA)

      report = @options[:report]
      reason = @options[:not_run_reason]
      raise Shaka::Error, 'Supply either --report or --not-run-reason, not both' if report && reason

      return report_result(report, head) if report

      raise Shaka::Error, '--not-run-reason is required when no report exists' if reason.to_s.strip.empty?

      { 'status' => 'not_completed', 'head' => head, 'reason' => reason.strip,
        'same_model_fallback_available' => true }
    end

    private

    def report_result(path, head)
      reviewer = ReviewerSelection.parse(@options.fetch(:reviewer)).values.join('/')
      text = File.read(path, encoding: 'UTF-8')
      unless LocalReviewAttestation.valid?(text, head:, reviewer:)
        return { 'status' => 'not_completed', 'head' => head,
                 'reason' => 'Report has no matching current-head review attestation',
                 'same_model_fallback_available' => true }
      end

      { 'status' => 'reported', 'head' => head, 'reviewer' => reviewer,
        'evidence' => 'host_report', 'cli_invocation_verified' => false, 'report' => path }
    end
  end

  # Requires the report to end with a reviewer-supplied exact-head attestation.
  module LocalReviewAttestation
    def self.valid?(text, head:, reviewer:)
      pattern = /(?:\A|\n)REVIEWED #{Regexp.escape(head)} BY #{Regexp.escape(reviewer)} EFFORT \S+ FINDINGS \d+\s*\z/
      text.match?(pattern)
    end
  end
end
