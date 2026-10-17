# frozen_string_literal: true

require_relative '../public_comments/threads'

module Shaka
  # Adds the review-thread fact to the handoff report.
  class Handoff
    # Owes each open review thread this account never answered after its opening comment, the
    # test `resolve` applies. An answered thread may stay open on purpose, so merge approval only
    # counts those for the agent to confirm.
    module ReviewThreads
      private

      def threads_fact
        answered, owed = answered_and_owed
        @notes << "#{answered.length} answered review threads remain open; confirm each is meant to stay open." if
          merge_requested? && answered.any?
        return if owed.empty?

        owe("#{owed.length} unanswered thread#{'s' if owed.length > 1}",
            "Reply on review threads this account never answered: #{owed.join(', ')}.")
      rescue Error => e
        note(nil, "Review threads are unread: #{e.message}")
      end

      def answered_and_owed
        reader = PublicComments::Threads.new(@github)
        open = reader.call.first.reject { |thread| thread['is_resolved'] }.map { |thread| thread['thread_id'] }
        account = @github.viewer_login
        open.partition { |id| reader.replies.fetch(id).include?(account) }
      end
    end

    include ReviewThreads
  end
end
