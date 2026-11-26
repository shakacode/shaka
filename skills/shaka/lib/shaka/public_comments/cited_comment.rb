# frozen_string_literal: true

require_relative 'authors'
require_relative 'trust_lookup'

module Shaka
  module PublicComments
    # Gives a reply the text of a comment it cites only when `comments` would show that text.
    #
    # A reply copies a cited comment's heading and reviewer line into the agent's own post. Without
    # this screen, citing the URL of a comment whose prose `comments` withheld published that prose.
    class CitedComment
      include TrustLookup

      KEYS = { 'issuecomment' => 'issue_comments', 'pullrequestreview' => 'review_summaries',
               'discussion_r' => 'inline_comments' }.freeze

      def initialize(github, trust_config: nil, machine_path: TrustConfig::MACHINE_PATH)
        @github = github
        @trust_config = trust_config
        @machine_path = machine_path
      end

      # The comment's text, or an empty string for an author `comments` excludes.
      def body(comment, fragment)
        readable?(comment, fragment) ? comment['body'].to_s : ''
      end

      private

      def readable?(comment, fragment)
        return true unless public_repository?
        return true if own?(comment)

        admitted?(comment, KEYS.fetch(fragment))
      end

      def public_repository?
        @public_repository = public? if @public_repository.nil?
        @public_repository
      end

      # This account wrote its own comments, such as a published local review.
      def own?(comment)
        user = comment['user']
        user.is_a?(Hash) && user['login'].is_a?(String) && user['login'] == @github.viewer_login
      end

      # The screen removes an excluded item's body, so it gets a copy.
      def admitted?(comment, key)
        index = key == 'inline_comments' ? { comment['id'] => { 'thread_id' => nil, 'is_resolved' => false } } : {}
        Authors.new(@github, public_repo: true, trust_config: config)
               .screen({ key => [comment.dup] }, thread_index: index).fetch('excluded_interactions').empty?
      end
    end
  end
end
