# frozen_string_literal: true

require_relative 'attention'
require_relative 'merge_wait_review'
require_relative 'ready_time'
require_relative 'status'

module Shaka
  # Checks what the maintainer would see before applying the merge approval label.
  class MergeHandoff
    def initialize(github, config:, review:, ci_review_wait:)
      @github = github
      @status = Status.new(github, seam_required_checks: config&.merge&.fetch('required_checks', nil))
      @review = MergeWaitReview.new(github, **review)
      @ready_gate = ReadyTime.gate(config, override: ci_review_wait)
    end

    def call
      snapshot = @status.call
      raise Error, 'Pull request is not open.' unless snapshot['state'] == 'OPEN'

      review = @review.check!(snapshot)
      checks = snapshot['requiredChecks']
      RequiredChecks.verify_passing!(checks)
      required = checks.map { |check| check.fetch('name') }
      ReadyTime.verify_fresh!(@github, @ready_gate, head: snapshot.fetch('headRefOid'), required:)
      Attention.new(@github).call(state: 'merge', expected: snapshot).merge('review' => review)
    end
  end
end
