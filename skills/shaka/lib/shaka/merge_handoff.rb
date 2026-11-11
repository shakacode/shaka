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
      snapshot = @status.call
      raise Error, 'Pull request is not open.' unless snapshot['state'] == 'OPEN'

      review = @review.check!(snapshot)
      RequiredChecks.verify_passing!(snapshot['requiredChecks'])
      Attention.new(@github).call(state: 'merge', expected: snapshot).merge('review' => review)
    end
  end
end
