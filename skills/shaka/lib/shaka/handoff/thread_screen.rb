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
        @screens = {}
        @retried = Set.new
      end

      # posts maps each thread ID to its comments as [login, body], as PublicComments::Threads reads
      # them. unscreened maps a thread ID to the error that stopped its screen.
      def call(posts, account)
        result = Result.new([], [], {})
        return result if posts.empty? || !public?

        # One trust-settings failure stops the whole screen, not each thread in turn. Like `reply`, a
        # thread with only this account's comments needs no trust settings.
        config if posts.values.flatten(1).any? { |login, _| login != account }
        posts.each { |id, comments| sort(result, id, comments, account) }
        result
      end

      private

      def sort(result, id, comments, account)
        rows = screened(comments.map(&:first).reject { |login| login == account }.uniq)
        list = rows.all? { |row| row['verification_unavailable'] } ? result.unverified : result.excluded
        list << id if rows.any?
      rescue Error => e
        result.unscreened[id] = e.message
      end

      # Threads with the same other authors share one screen, so a PR with many threads from one
      # reviewer reads each permission once. After a failed read, returned or raised, the next
      # such thread asks GitHub once more; a second failure is kept, so an outage costs two reads,
      # not one per thread.
      def screened(logins)
        key = logins.sort_by(&:to_s)
        kept = @screens.fetch(key) { return keep(key, logins) }
        raise kept if kept.is_a?(Error)

        kept
      end

      def keep(key, logins)
        rows = screen(logins)
        failed = rows.any? { |row| row['verification_unavailable'] }
        @screens[key] = rows unless failed && @retried.add?(key)
        rows
      rescue Error => e
        @screens[key] = e unless @retried.add?(key)
        raise
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
