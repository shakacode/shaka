# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_submission'
require_relative 'review_pace'

module Shaka
  # Applies native GitHub gates; the calling skill must establish merge authority.
  class Merge
    def initialize(github, pace: nil, seam_pace: nil)
      @github = github
      @pace = ReviewPace.effective(seam: seam_pace, override: pace)
      @submission = MergeSubmission.new(github)
    end

    def call(head:, base:, walkthrough:)
      verify_arguments(head, base)

      initial = @github.snapshot
      verify_snapshot(initial, head)
      verify_validated_base(initial, base)
      verify_checks(@github.required_checks)
      verify_walkthrough(@github.review(walkthrough), head, walkthrough)
      current = @github.snapshot
      return reconcile_queued_replay(initial, current, head) if initial['isInMergeQueue']

      verify_snapshot(current, head)
      verify_same_base(initial, current)
      @submission.call(current, head)
    end

    private

    def verify_arguments(head, base)
      raise Error, 'Expected a full commit SHA' unless head.is_a?(String) && head.match?(/\A[0-9a-f]{40}\z/)
      return if base.is_a?(String) && !base.strip.empty?

      raise Error, 'Expected the base branch the change was validated against'
    end

    # verify_same_base catches a base moving during this run. This catches the case that run
    # cannot see: a PR whose target was never the branch the change was validated against,
    # because it was retargeted earlier or a stated base was never applied to an adopted PR.
    def verify_validated_base(pull, base)
      return if pull['baseRefName'] == base

      raise Error, "PR targets #{pull['baseRefName'].inspect}, not the validated base #{base.inspect}"
    end

    def reconcile_queued_replay(initial, current, head)
      unless current['state'] == 'MERGED'
        verify_snapshot(current, head)
        verify_same_base(initial, current)
      end

      @submission.reconcile_queued(initial, current, head)
    end

    def verify_snapshot(pull, head)
      verify_identity(pull, head)
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

    def verify_same_base(initial, current)
      return if current['baseRefName'] == initial['baseRefName']

      raise Error, 'PR base changed; refresh verification and walkthrough'
    end

    def verify_submission_mode(pull)
      raise Error, 'Native protection must be enforced for this actor' unless pull['viewerCanMergeAsAdmin'] == false

      queue_enabled = pull['isMergeQueueEnabled']
      in_queue = pull['isInMergeQueue']
      verify_queue_state(pull, queue_enabled, in_queue)
      return if in_queue
      return if pull.key?('autoMergeRequest') && pull['autoMergeRequest'].nil?

      raise Error, 'Existing or unknown delayed auto-merge blocks immediate merge'
    end

    def verify_queue_state(pull, queue_enabled, in_queue)
      booleans = [true, false]
      raise Error, 'Merge queue state is unknown' unless booleans.include?(queue_enabled) && booleans.include?(in_queue)
      raise Error, 'Merge queue state is inconsistent' if in_queue && !queue_enabled

      verify_queue_entry_absence(pull) unless in_queue
    end

    def verify_queue_entry_absence(pull)
      return if pull.key?('mergeQueueEntry') && pull['mergeQueueEntry'].nil?

      raise Error, 'Merge queue state is inconsistent'
    end

    def verify_native_state(pull)
      unless pull['isInMergeQueue']
        verify_merge_state(pull, ReviewPace.allowed_merge_states(@pace, pull['isMergeQueueEnabled']))
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

    def verify_checks(checks)
      unless checks.is_a?(Array) && !checks.empty?
        raise Error, 'No observable required checks; native readiness is unknown'
      end

      checks.each do |check|
        next if passing_check?(check)

        raise Error, "Required check is not passing or is malformed: #{check.inspect}"
      end
    end

    def passing_check?(check)
      return false unless check.is_a?(Hash) && check['name'].is_a?(String) && !check['name'].strip.empty?

      case check['state']
      when 'SUCCESS' then check['bucket'] == 'pass'
      when 'NEUTRAL', 'SKIPPED' then check['bucket'] == 'skipping'
      else false
      end
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
