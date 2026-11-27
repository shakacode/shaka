# frozen_string_literal: true

require_relative '../configuration/trust_config'
require_relative '../public_comments/authors'
require_relative '../public_comments/trust_lookup'

module Shaka
  class Handoff
    # Finds the review threads `reply` would refuse to answer: in a public repository, threads with
    # a comment from someone other than this account whom `comments` excludes. It screens the way
    # `PublicComments::ReplyGuard` does. A failed permission read is not evidence of exclusion, so
    # a thread with one stays with the agent.
    class ThreadScreen
      include PublicComments::TrustLookup

      def initialize(github, trust_config: nil, machine_path: PublicComments::TrustConfig::MACHINE_PATH)
        @github = github
        @trust_config = trust_config
        @machine_path = machine_path
      end

      # posts maps each thread ID to its comments as [login, body], as PublicComments::Threads reads them.
      def excluded(posts, account)
        return [] if posts.empty? || !public?

        items, index = items_for(posts, account)
        return [] if items.empty?

        unverified, excluded = screen(items, index).partition { |row| row['verification_unavailable'] }
        thread_ids(excluded) - thread_ids(unverified)
      end

      private

      # Authors reads REST comments, so each post becomes one with a numbered ID and the user type
      # GraphQL implies: only an app account's login carries the [bot] suffix.
      def items_for(posts, account)
        logins = posts.flat_map { |thread_id, comments| comments.map { |login, _| [thread_id, login] } }
        others = logins.reject { |_, login| login == account }
        items = others.each_with_index.map { |(_, login), position| { 'id' => position + 1, 'user' => user(login) } }
        index = others.each_with_index.to_h do |(thread_id, _), position|
          [position + 1, { 'thread_id' => thread_id, 'is_resolved' => false }]
        end
        [items, index]
      end

      def screen(items, index)
        PublicComments::Authors.new(@github, public_repo: true, trust_config: config)
                               .screen({ 'inline_comments' => items }, thread_index: index)
                               .fetch('excluded_interactions')
      end

      def thread_ids(rows) = rows.map { |row| row['thread_id'] }.uniq

      def user(login)
        return unless login

        { 'login' => login, 'type' => login.end_with?('[bot]') ? 'Bot' : 'User' }
      end
    end
  end
end
