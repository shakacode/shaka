# frozen_string_literal: true

require_relative 'attention'
require_relative 'merge_wait_review'
require_relative 'status'

module Shaka
  # Checks what the maintainer would see before applying the merge approval label.
  class MergeHandoff
    def initialize(github, seam_required_checks:, review:)
      @github = github
      @status = Status.new(github, seam_required_checks:)
      @review = MergeWaitReview.new(github, **review)
    end

    def call
      reviewed = @github.snapshot
      open!(reviewed)
      review = @review.check!(reviewed)
      snapshot = @status.call
      verify_same_target!(reviewed, snapshot)
      RequiredChecks.verify_passing!(snapshot['requiredChecks'])
      Attention.new(@github).call(state: 'merge', expected: snapshot).merge('review' => review)
    end

    private

    def verify_same_target!(reviewed, snapshot)
      open!(snapshot)
      head, base = reviewed.values_at('headRefOid', 'baseRefName')
      raise Error, 'PR head changed while preparing the merge wait; retry.' if head != snapshot['headRefOid']
      raise Error, 'PR base changed while preparing the merge wait; retry.' if base != snapshot['baseRefName']
    end

    def open!(snapshot)
      raise Error, 'Pull request is not open.' unless snapshot['state'] == 'OPEN'
    end
  end
end
