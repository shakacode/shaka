# frozen_string_literal: true

require_relative '../handoff/wip_note'

module Shaka
  class PrWatch
    # Watches discussion after a ready handoff, without treating terminal checks as a wake.
    module Feedback
      private

      def configure_feedback(settings)
        @baseline = settings[:baseline]
        @comments_only = settings[:comments_only]
        @owner = settings[:owner]
      end

      def observe_feedback
        reason = feedback_stop_reason
        return reason if reason

        fresh = new_comments?
        reason = feedback_stop_reason
        return reason if reason

        update_pending(fresh, false)
        nil
      end

      def feedback_stop_reason
        pull = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")
        return 'closed' unless pull['state'] == 'open'
        return 'head_moved' if pull.dig('head', 'sha') != @head

        owner = Handoff::WipNote.value(pull['body'], 'owner')
        raise Error, 'WIP Details owner is missing; feedback coverage is unavailable.' unless owner

        'ownership_transferred' unless owner == @owner
      end
    end
  end
end
