# frozen_string_literal: true

require_relative '../public_comments/threads'
require_relative '../publication/agent_post'
require_relative 'thread_screen'

module Shaka
  # Adds the review-thread fact to the handoff report.
  class Handoff
    # Owes each open review thread the agent has not answered, or where anyone but a bot spoke
    # after its last answer. The agent posts from a person's account, so its posts are this
    # account's marked ones; an unmarked post from the same account is the person's. A bot's
    # comment after the answer, such as a thank-you, owes nothing. An answered thread may stay
    # open on purpose, so merge approval only counts those for the agent to confirm. A public
    # thread that includes an excluded author is a note for a person instead, because `reply`
    # refuses to post there and `resolve` needs a reply first.
    module ReviewThreads
      attr_writer :thread_screen

      private

      def threads_fact
        answered, owed, unknown = classified_threads
        thread_notes(answered, unknown)
        owed -= excluded_threads(owed)
        return if owed.empty?

        owe("#{owed.length} unanswered thread#{'s' if owed.length > 1}",
            "Reply on review threads waiting for an answer: #{owed.join(', ')}.")
      rescue Error => e
        note(nil, "Review threads are unread: #{e.message}")
      end

      def thread_notes(answered, unknown)
        @notes << "Check by hand for a comment past 100 on #{unknown.join(', ')}." if unknown.any?
        return unless merge_requested? && answered.any?

        @notes << "#{answered.length} answered review thread#{'s' if answered.length > 1} still open; " \
                  'confirm each is meant to stay open.'
      end

      # A failed screen keeps every thread owed, so an unread trust setting hides none of them.
      def excluded_threads(owed)
        excluded = thread_screen.excluded(@thread_posts.slice(*owed), @github.viewer_login)
        @notes << excluded_note(excluded) if excluded.any?
        excluded
      rescue Error => e
        @notes << "Thread authors are unscreened: #{e.message}"
        []
      end

      def excluded_note(ids)
        "Review thread#{'s' if ids.length > 1} #{ids.join(', ')} #{ids.length > 1 ? 'include' : 'includes'} " \
          'an author `comments` excludes, so the agent cannot reply or resolve there. ' \
          'A maintainer can answer and resolve it on GitHub, or add the author to the trusted actors.'
      end

      def thread_screen = @thread_screen ||= ThreadScreen.new(@github)

      # A comment past the first page is unseen, so a truncated thread is unknown, not owed.
      def classified_threads
        reader = PublicComments::Threads.new(@github)
        account = @github.viewer_login
        @thread_posts = reader.posts
        unknown, seen = open_ids(reader).partition { |id| reader.truncated.include?(id) }
        answered, owed = seen.partition { |id| thread_answered?(reader.posts.fetch(id), account) }
        [answered, owed, unknown]
      end

      # A marked post from another account does not answer, so it cannot clear a person's comment.
      def thread_answered?(posts, account)
        ours = ->(login, body) { login == account && AgentPost.marked?(body) }
        last = posts.rindex { |login, body| ours.call(login, body) }
        last && posts.drop(last + 1).all? { |login, body| AgentPost.bot?(login) || ours.call(login, body) }
      end

      def open_ids(reader)
        reader.call.first.reject { |thread| thread['is_resolved'] }.map { |thread| thread['thread_id'] }
      end
    end

    include ReviewThreads
  end
end
