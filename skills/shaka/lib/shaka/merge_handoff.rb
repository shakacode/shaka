# frozen_string_literal: true

require_relative 'attention'
require_relative 'merge_wait_review'
require_relative 'status'

module Shaka
  # Checks what the maintainer would see before applying the merge approval label.
  # Where GitHub refuses GraphQL, it reads over REST and names the fields REST cannot read; GitHub still
  # enforces review approval and the merge queue when the maintainer clicks merge.
  class MergeHandoff
    def initialize(github, seam_required_checks:, review:)
      @github = github
      @status = Status.new(github, seam_required_checks:, rest_fallback: true)
      @review = MergeWaitReview.new(github, **review)
    end

    def call
      reviewed = @github.state_snapshot
      open!(reviewed)
      review = @review.check!(reviewed)
      snapshot = @status.call
      verify_same_target!(reviewed, snapshot)
      RequiredChecks.verify_passing!(snapshot['requiredChecks'])
      Attention.new(@github).call(state: 'merge', expected: snapshot)
               .merge('review' => review, **snapshot.slice('readOver', 'unknownFields'))
    end

    private

    def verify_same_target!(reviewed, snapshot)
      open!(snapshot)
      head, base = reviewed.values_at('headRefOid', 'baseRefName')
      raise Error, 'PR head changed while preparing the merge wait; retry.' if head != snapshot['headRefOid']
      raise Error, 'PR base changed while preparing the merge wait; retry.' if base != snapshot['baseRefName']
    end

    # A draft cannot be merged, so asking a person to merge it contradicts what GitHub shows them.
    def open!(snapshot)
      raise Error, 'Pull request is not open.' unless snapshot['state'] == 'OPEN'
      return if snapshot['isDraft'] == false

      raise Error, "PR ##{@github.number} is a draft, which GitHub cannot merge. Mark it ready for review " \
                   "(`gh pr ready #{@github.number} --repo #{@github.repository}`), wait for the checks and " \
                   'reviews that starts, then retry.'
    end
  end
end
