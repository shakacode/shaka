# frozen_string_literal: true

require_relative '../merge_wait_review'

module Shaka
  # Reports the published evidence a PR labeled as waiting for merge approval still lacks.
  module HandoffMergeWait
    private

    # Agent work with findings open is not a merge wait. No review may be a stated skip, which GitHub
    # cannot show, so that is reported rather than owed; `attention --state merge` asked for the reason.
    def review_fact(snapshot)
      return unless @review && merge_requested?

      @review.check!(snapshot)
      nil
    rescue MergeReviewEvidence::Missing
      note('no local review', "No published local review covers #{snapshot['headRefOid']}; unless review was " \
                              'skipped on purpose, remove the label and publish it.')
    rescue Error => e
      owe('local review owed', e.message)
    end

    def checkpoint_fact(live)
      return unless @checkpoint && merge_requested?

      @checkpoint.call(live)
      "checkpoint #{live[0, Handoff::SHORT]}"
    rescue Error => e
      owe('checkpoint owed', e.message)
    end
  end
end
