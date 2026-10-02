# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_target'
require_relative 'merge_submission'
require_relative 'ci_review_wait'
require_relative 'required_checks'
require_relative 'merge_review_evidence'
require_relative 'merge_required_checks'
require_relative 'merge_limits'
require_relative 'merge_submission_mode'

module Shaka
  # Applies native GitHub gates; the calling skill must establish merge authority.
  class Merge
    include MergeRequiredChecks
    include MergeSubmissionMode

    # `review` takes MergeReviewEvidence's `required`, `waiver`, and checkout `root`.
    def initialize(github, ci_review_wait: nil, seam_wait: nil, review: {}, merge_policy: {})
      @allow_admin_actor = merge_policy.fetch('allow_admin_actor', false)
      raise Error, 'merge.allow_admin_actor must be a boolean' unless [true, false].include?(@allow_admin_actor)

      @github = github
      @seam_required_checks = merge_policy['required_checks']
      @ci_review_wait = CiReviewWait.effective(seam: seam_wait, override: ci_review_wait)
      @review_evidence = MergeReviewEvidence.new(github, **review)
      @submission = MergeSubmission.new(github)
    end

    # `squash_message` is a SquashMessage, or nil for the repository's squash default.
    def call(head:, base:, walkthrough:, limits: MergeLimits.new, squash_message: nil)
      @target = MergeTarget.required!(head, base, limits)
      @submission.message = squash_message
      initial = @github.snapshot
      verify_snapshot(initial, head, @target)
      evidence = verify_reviews(head, base, walkthrough, verify_gate)
      current = @github.snapshot
      submit(initial, current, head).merge(evidence, 'actor_capability' => @actor_capability)
    end

    private

    def submit(initial, current, head)
      return reconcile_queued_replay(initial, current, head) if initial['isInMergeQueue']

      verify_snapshot(current, head)
      @target.unchanged!(initial, current)
      @submission.call(current, head)
    end

    def verify_gate
      gate = RequiredChecks.new(@github, seam_names: @seam_required_checks).call
      verify_checks(gate.fetch('checks'))
      gate
    end

    # The walkthrough explains the change; the attestation records that a separate review ran.
    # GitHub cannot catch a seam check that fails while these are read, so it is read again.
    def verify_reviews(head, base, walkthrough, gate)
      verify_walkthrough(@github.review(walkthrough), head, walkthrough)
      evidence = { 'review_evidence' => @review_evidence.call(head, base:) }
      verify_gate if gate['source'] == 'seam'
      evidence
    end

    def reconcile_queued_replay(initial, current, head)
      unless current['state'] == 'MERGED'
        verify_snapshot(current, head)
        @target.unchanged!(initial, current)
      end

      @submission.reconcile_queued(initial, current, head)
    end

    def verify_snapshot(pull, head, target = nil)
      verify_identity(pull, head)
      target&.validated!(pull)
      verify_submission_mode(pull)
      verify_native_state(pull)
    end

    def verify_identity(pull, head)
      raise Error, 'PR head changed; refresh verification and walkthrough' unless pull['headRefOid'] == head
      raise Error, 'PR must be open and not a draft' unless pull['state'] == 'OPEN' && pull['isDraft'] == false

      verify_pull_fields(pull)
    end

    def verify_pull_fields(pull)
      raise Error, 'GitHub PR identity is missing' unless pull['id'].is_a?(String) && !pull['id'].empty?
      raise Error, 'GitHub PR base is missing' unless pull['baseRefName'].is_a?(String) && !pull['baseRefName'].empty?
    end

    def verify_native_state(pull)
      unless pull['isInMergeQueue']
        verify_merge_state(pull, CiReviewWait.allowed_merge_states(@ci_review_wait, pull['isMergeQueueEnabled']))
      end

      verify_review_state(pull)
    end

    def verify_merge_state(pull, allowed)
      return if allowed.include?(pull['mergeStateStatus'])

      raise Error, "GitHub merge state is not #{allowed.join(' or ')}: #{pull['mergeStateStatus'].inspect}"
    end

    def verify_review_state(pull)
      return if pull.key?('reviewDecision') && [nil, 'APPROVED'].include?(pull['reviewDecision'])

      raise Error, 'Required reviews are not satisfied or their state is unknown'
    end

    def verify_walkthrough(review, head, id)
      unless review.is_a?(Hash) && review['id'].to_s == id.to_s && review['commit_id'] == head
        raise Error, 'Walkthrough must identify a review on this PR at the expected head'
      end
      return if review['state'] == 'COMMENTED' && review['body'].is_a?(String) && !review['body'].strip.empty?

      raise Error, 'Walkthrough must be a submitted COMMENT review with a nonempty body'
    end
  end
end
