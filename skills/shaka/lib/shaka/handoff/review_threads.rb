# frozen_string_literal: true

require_relative '../public_comments/threads'

module Shaka
  # Adds the review-thread fact to the handoff report.
  class Handoff
    # Owes each open review thread this account neither opened nor answered, the reply test
    # `resolve` applies. An answered thread may stay open on purpose, so merge approval only
    # counts those for the agent to confirm.
    module ReviewThreads
      private

      def threads_fact
        answered, owed = answered_and_owed
        if merge_requested? && answered.any?
          @notes << "#{answered.length} answered review thread#{'s' if answered.length > 1} still open; " \
                    'confirm each is meant to stay open.'
        end
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
        open.partition { |id| reader.authors.fetch(id).include?(account) }
      end
    end

    include ReviewThreads
  end
end
