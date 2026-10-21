# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Handoff
    # Says whether merge.auto_max_review_floor would have let Auto merge a PR waiting for an Ask
    # click, so a maintainer can try a floor on real PRs before choosing Auto.
    module AutoMergeNote
      # The trusted MergeReviewFloor; nil, or one at the top level, adds no note.
      attr_writer :review_floor

      private

      # Runs after the labels are read; returns nil, because the result is a note, not a fact.
      def auto_merge_note(head)
        return unless @review_floor&.holds_any? && merge_requested?

        reason = @review_floor.hold(@review_floor.paths(@github, head))
        @notes << (reason ? "Auto would hand this PR back: #{reason}." : 'Auto would merge this PR by its paths.')
        nil
      rescue Error => e
        @notes << "Auto would hand this PR back: #{e.message}."
        nil
      end
    end
  end
end
