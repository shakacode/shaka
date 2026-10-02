# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Checks actor capability and immediate native submission state on each live snapshot.
  module MergeSubmissionMode
    private

    def verify_submission_mode(pull)
      verify_actor_capability(pull['viewerCanMergeAsAdmin'])

      queue_enabled = pull['isMergeQueueEnabled']
      in_queue = pull['isInMergeQueue']
      verify_queue_state(pull, queue_enabled, in_queue)
      return if in_queue
      return if pull.key?('autoMergeRequest') && pull['autoMergeRequest'].nil?

      raise Error, 'Existing or unknown delayed auto-merge blocks immediate merge'
    end

    def verify_actor_capability(capability)
      raise Error, 'Admin actor capability is unknown; merge.allow_admin_actor cannot authorize it' unless
        [true, false].include?(capability)
      if capability && !@allow_admin_actor
        raise Error, 'Admin capability caused refusal; set merge.allow_admin_actor: true ' \
                     'in the trusted default-branch seam'
      end

      @actor_capability = { 'allow_admin_actor' => @allow_admin_actor, 'viewerCanMergeAsAdmin' => capability,
                            'decision' => capability ? 'allowed_by_trusted_opt_in' : 'non_admin_actor' }
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
  end
end
