# frozen_string_literal: true

require_relative '../github/squash_comment'
require_relative '../public_comments/bounded_list'
require_relative '../publication/agent_post'

module Shaka
  # Adds the conversation-comment fact to the handoff report.
  class Handoff
    # Owes each conversation comment the PR's person wrote that no later agent reply links, the
    # answer test of the description's Human comments list. The person is the PR author or this
    # account, whose unmarked posts are theirs because the agent posts from it too. Bots and other
    # people's comments stay with `comments` and the description.
    module Conversation
      private

      def comment_fact(snapshot)
        owed = unanswered_comments(snapshot.dig('author', 'login'))
        return if owed.empty?

        owe("#{owed.length} unanswered comment#{'s' if owed.length > 1}",
            'Reply with `reply` to conversation comments waiting for an answer: ' \
            "#{owed.map { |comment| comment['html_url'] }.join(', ')}.")
      rescue Error => e
        note(nil, "Conversation comments are unread: #{e.message}")
      end

      def unanswered_comments(author)
        account = @github.viewer_login
        comments = conversation_comments
        comments.select do |comment|
          persons_comment?(comment, [author, account]) && !comment_answered?(comment, comments, account)
        end
      end

      def persons_comment?(comment, people)
        login = comment.dig('user', 'login')
        people.include?(login) && !AgentPost.bot?(login) && !AgentPost.marked?(comment['body'])
      end

      def comment_answered?(comment, comments, account)
        comments.any? do |other|
          other['id'].to_i > comment['id'].to_i && other.dig('user', 'login') == account &&
            AgentPost.marked?(other['body']) && AgentPost.links?(other['body'], comment['html_url'])
        end
      end

      def conversation_comments
        path = "repos/#{@github.repository}/issues/#{@github.number}/comments"
        PublicComments::BoundedList.new(@github, max_pages: SquashComment::COMMENT_PAGES, label: 'Comment listing')
                                   .call(path)
      end
    end

    include Conversation
  end
end
