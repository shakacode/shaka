# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_review_evidence'

module Shaka
  # Whether local review lets a PR wait for a person's merge approval. It reads the evidence `merge`
  # reads, so unrecorded findings, which `review publish` refuses, show as no review for this head.
  class MergeWaitReview
    class OpenFindings < Error; end

    # required is the trusted review.required, or nil when no trusted settings were read.
    def initialize(github, required: nil, waiver: nil, root: nil)
      @required = required
      @evidence = MergeReviewEvidence.new(github, waiver:, root:)
    end

    # Returns the evidence relied on, or raises what stands between this PR and the merge wait.
    def check!(snapshot)
      return unless snapshot['state'] == 'OPEN'

      evidence = @evidence.call(snapshot.fetch('headRefOid'), base: snapshot['baseRefName'])
      refuse_open(evidence['pending']) if evidence['pending'].to_i.positive?
      evidence
    rescue MergeReviewEvidence::Missing
      raise unless @required == 'none'

      { 'basis' => 'not_required' }
    end

    private

    def refuse_open(count)
      noun = count == 1 ? '1 finding' : "#{count} findings"
      raise OpenFindings, "The local review still has #{noun} needing attention, so this PR is not waiting only " \
                          'on a merge. Fix and review them, or settle each with `review record`, then ' \
                          '`review publish`.'
    end
  end
end
