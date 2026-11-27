# frozen_string_literal: true

require_relative '../configuration/trust_config'
require_relative '../public_comments/authors'
require_relative '../public_comments/trust_lookup'

module Shaka
  class Handoff
    # Sorts review threads by whether `reply` would post in them. In a public repository it screens
    # each thread's comments from anyone but this account, one thread at a time as
    # `PublicComments::ReplyGuard` does, so other threads cannot change one thread's lookups.
    # `reply` refuses a thread with an author whose permission read failed, but that failure is
    # not evidence of exclusion, so such a thread is reported apart from a confirmed exclusion.
    class ThreadScreen
      include PublicComments::TrustLookup

      Result = Struct.new(:excluded, :unverified, :unscreened)

      def initialize(github, trust_config: nil, machine_path: PublicComments::TrustConfig::MACHINE_PATH)
        @github = github
        @trust_config = trust_config
        @machine_path = machine_path
      end

      # posts maps each thread ID to its comments as [login, body], as PublicComments::Threads reads
      # them. unscreened maps a thread ID to the error that stopped its screen.
      def call(posts, account)
        result = Result.new([], [], {})
        return result if posts.empty? || !public?

        posts.each { |id, comments| sort(result, id, comments, account) }
        result
      end

      private

      def sort(result, id, comments, account)
        rows = screen(comments.map(&:first).reject { |login| login == account })
        list = rows.all? { |row| row['verification_unavailable'] } ? result.unverified : result.excluded
        list << id if rows.any?
      rescue Error => e
        result.unscreened[id] = e.message
      end

      # Authors reads REST comments, so each login becomes one with a numbered ID and the user type
      # GraphQL implies: only an app account's login carries the [bot] suffix.
      def screen(logins)
        return [] if logins.empty?

        items = logins.each_with_index.map { |login, position| { 'id' => position + 1, 'user' => user(login) } }
        index = items.to_h { |item| [item['id'], { 'thread_id' => 'screened', 'is_resolved' => false }] }
        PublicComments::Authors.new(@github, public_repo: true, trust_config: config)
                               .screen({ 'inline_comments' => items }, thread_index: index)
                               .fetch('excluded_interactions')
      end

      def user(login)
        return unless login

        { 'login' => login, 'type' => login.end_with?('[bot]') ? 'Bot' : 'User' }
      end
    end
  end
end
