# frozen_string_literal: true

require_relative 'error'
require_relative 'local_review/evidence'
require_relative 'merge_review_evidence'

module Shaka
  # Whether local review lets a PR wait for a person's merge approval. The newest published review's
  # open findings refuse it whatever commit that review read. Otherwise it applies `merge`'s evidence
  # rule, so unrecorded findings, which `review publish` refuses, show as no review for this head.
  class MergeWaitReview
    class OpenFindings < Error; end

    # required is the trusted review.required, or nil when no trusted settings were read.
    def initialize(github, required: nil, waiver: nil, root: nil)
      @github = github
      @required = required
      @evidence = MergeReviewEvidence.new(github, waiver:, root:)
    end

    # Returns the evidence relied on, or raises what stands between this PR and the merge wait.
    def check!(snapshot)
      return unless snapshot['state'] == 'OPEN'

      refuse_open_findings!
      @evidence.call(snapshot.fetch('headRefOid'), base: snapshot['baseRefName'])
    rescue MergeReviewEvidence::Missing
      raise unless @required == 'none'

      { 'basis' => 'not_required' }
    end

    # No waiver or review.required value excuses a published open finding, and an unreadable list refuses.
    def refuse_open_findings!
      count = published_open_findings
      return if count.zero?

      noun = count == 1 ? '1 finding' : "#{count} findings"
      raise OpenFindings, "The local review still has #{noun} needing attention. Fix and review them, or settle " \
                          'each with `review record`, then `review publish`.'
    end

    private

    # The review published last speaks for the loop. Republishing keeps a comment's place in GitHub's
    # listing, so its update time decides, and a tie reads as the larger count.
    def published_open_findings
      account = @github.viewer_login
      reviews = @github.issue_comments.filter_map do |comment|
        count = LocalReviewEvidence.pending_count(comment['body'].to_s) if comment.dig('user', 'login') == account
        [comment['updated_at'].to_s, count] if count
      end
      reviews.max&.last.to_i
    end
  end
end
