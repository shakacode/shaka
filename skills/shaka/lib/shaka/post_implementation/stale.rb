# frozen_string_literal: true

require_relative '../error'
require_relative '../local_review/bot_history'
require_relative '../publication/comment_history'
require_relative 'history'

module Shaka
  # Hides this account's newest checkpoint once the PR head moves past it, so nobody copies its merge message
  # for commits it never judged. GitHub keeps the body behind its disclosure, and the next checkpoint still
  # folds it into history.
  class PostImplementationStale
    HEAD = /\A<!-- shaka:reply:post-implementation-([0-9a-f]{7})-/

    def initialize(github) = @github = github

    def call
      pull = @github.snapshot
      return { 'state' => 'none' } unless pull['state'] == 'OPEN'

      latest = latest_checkpoint
      return { 'state' => 'none' } unless latest

      id = latest['id']
      return { 'state' => 'current', 'comment' => id } if pull['headRefOid'].to_s.start_with?(latest['body'][HEAD, 1])

      { 'state' => minimize(latest['node_id']), 'comment' => id }
    rescue Error => e
      { 'state' => 'unavailable', 'reason' => e.message }
    end

    private

    def latest_checkpoint
      account = @github.viewer_login
      checkpoints = @github.issue_comments.select do |comment|
        comment.dig('user', 'login') == account && comment['body'].to_s.match?(PostImplementationHistory::KEY)
      end
      checkpoints.max_by { |comment| CommentHistory.order(comment) }
    end

    def minimize(id)
      node = read(id)
      return 'already_minimized' if node['isMinimized']
      raise Error, 'GitHub does not permit this account to minimize the stale checkpoint.' unless
        node['viewerCanMinimize']

      @github.graphql(BotReviewHistory::MUTATION, id:)
      raise Error, 'GitHub did not confirm the stale checkpoint was minimized.' unless read(id)['isMinimized']

      'minimized'
    end

    def read(id)
      raise Error, 'Checkpoint comment has no node identifier.' unless id.is_a?(String) && !id.empty?

      node = @github.graphql(BotReviewHistory::QUERY, id:)['node']
      raise Error, 'Checkpoint comment is unavailable.' unless node.is_a?(Hash)

      node
    end
  end
end
