# frozen_string_literal: true

require_relative 'error'
require_relative 'review_thread/lookup'

module Shaka
  # Marks one inline review thread resolved after the agent has replied from the authenticated
  # account. The agent posts under a person's login, so only a marked reply is the agent's, as
  # `handoff` counts it; an unmarked reply is the person's and reads as theirs.
  class ReviewThread
    THREAD_ID = /\A[A-Za-z0-9_-]{1,200}\z/
    MUTATION = <<~GRAPHQL
      mutation($id: ID!) {
        resolveReviewThread(input: { threadId: $id }) {
          thread { id isResolved }
        }
      }
    GRAPHQL

    def self.resolve(github, thread_id)
      new(github, thread_id).resolve
    end

    def initialize(github, thread_id)
      @github = github
      @thread_id = thread_id
    end

    def resolve
      check_id
      @account = account
      thread = Lookup.new(@github, @thread_id).call
      refuse_resolved(thread)
      check_reply(thread)
      mutate
      { 'thread_id' => @thread_id, 'is_resolved' => true }
    end

    private

    def check_id
      return if @thread_id.is_a?(String) && @thread_id.match?(THREAD_ID)

      raise Error, 'Expected a review-thread ID.'
    end

    def account
      login = @github.api('user')['login']
      return login if login.is_a?(String) && !login.empty?

      raise Error, 'GitHub did not return the authenticated account.'
    end

    def refuse_resolved(thread)
      raise Error, 'The review thread is already resolved.' if thread['isResolved']
    end

    # Walkthrough history loads this file, and AgentPost loads walkthrough history, so the
    # reply check loads AgentPost only when it runs.
    def check_reply(thread)
      require_relative 'publication/agent_post'
      replies = own_replies(thread)
      return if replies.any? { |comment| AgentPost.marked?(comment['body']) }
      raise Error, 'Review-thread reply evidence is incomplete.' if more_comments?(thread)
      if replies.any?
        raise Error, "This account's reply has no AI identity line, so it counts as a person's. " \
                     "Post the agent's answer with `shaka reply` before resolving."
      end

      raise Error, 'Resolve a review thread only after this account has replied on it.'
    end

    # The first comment opens the thread. A later comment from this account is a reply.
    def own_replies(thread)
      thread.dig('comments', 'nodes').drop(1).select do |comment|
        comment.is_a?(Hash) && comment.dig('author', 'login') == @account
      end
    end

    def more_comments?(thread)
      thread.dig('comments', 'pageInfo', 'hasNextPage')
    end

    def mutate
      thread = @github.graphql(MUTATION, id: @thread_id).dig('resolveReviewThread', 'thread')
      return if resolved?(thread)

      raise Error, 'GitHub did not resolve the review thread.'
    end

    def resolved?(thread)
      thread.is_a?(Hash) && thread['id'] == @thread_id && thread['isResolved'] == true
    end
  end
end
