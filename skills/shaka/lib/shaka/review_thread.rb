# frozen_string_literal: true

require_relative 'error'
require_relative 'review_thread/lookup'

module Shaka
  # Marks one inline review thread resolved after the authenticated account has replied.
  class ReviewThread
    THREAD_ID = /\A[A-Za-z0-9_-]{1,200}\z/
    MUTATION = <<~GRAPHQL
      mutation($id: ID!) {
        resolveReviewThread(input: { threadId: $id }) {
          thread { id isResolved }
        }
      }
    GRAPHQL
    CONFIRM = <<~GRAPHQL
      query($id: ID!) {
        node(id: $id) {
          __typename
          ... on PullRequestReviewThread {
            id
            isResolved
            pullRequest { number }
          }
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
      confirm
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

    def check_reply(thread)
      return if authors(thread).include?(@account)
      raise Error, 'Review-thread reply evidence is incomplete.' if more_comments?(thread)

      raise Error, 'Resolve a review thread only after this account has replied on it.'
    end

    def authors(thread)
      thread.dig('comments', 'nodes').filter_map do |comment|
        comment.dig('author', 'login') if comment.is_a?(Hash)
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

    def confirm
      return if stored?(@github.graphql(CONFIRM, id: @thread_id)['node'])

      raise Error, 'The review thread is not resolved.'
    end

    def resolved?(thread)
      thread.is_a?(Hash) && thread['id'] == @thread_id && thread['isResolved'] == true
    end

    def stored?(node)
      resolved?(node) && node['__typename'] == 'PullRequestReviewThread' &&
        node.dig('pullRequest', 'number') == @github.number
    end
  end
end
