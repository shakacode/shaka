# frozen_string_literal: true

require_relative '../error'
require_relative '../public_comments/threads'
require_relative 'notes'

module Shaka
  module Walkthrough
    # Deletes the notes of a walkthrough a newer one replaced. The newer walkthrough posts its own
    # notes, so a kept older copy, even resolved, reads as a duplicate comment on the pull request.
    # A note with any reply stays: Shaka posts under a person's login, so a reply from this account
    # may be that person's.
    class NoteThreads
      # Rereads one thread, so a reply posted after the pull request's threads were listed still keeps its note.
      ALONE = <<~GRAPHQL
        query($id: ID!) {
          node(id: $id) { ... on PullRequestReviewThread { comments(first: 2) { totalCount nodes { author { login } } } } }
        }
      GRAPHQL

      def initialize(github, account)
        @github = github
        @account = account
      end

      # Adds each deleted note's comment ID to the collapse report as it goes, and each failure to
      # its unavailable list.
      def delete_all(reviews, report)
        reviews.select { |review| review.dig('user', 'login') == @account }.each do |review|
          delete(review) { |id| report['deleted_notes'] << id }
        rescue Error => e
          report['unavailable'] << "Review #{review['id']} notes: #{e.message}"
        end
      end

      # Yields the ID of each note it deletes.
      def delete(review)
        roots = note_roots(review)
        return if roots.empty?

        index = threads
        roots.select { |id| index[id] && unanswered?(index[id]) }.each do |id|
          next unless still_alone?(index[id]['thread_id'])

          @github.delete_comment(id)
          yield id
        end
      end

      private

      def note_roots(review)
        path = "repos/#{@github.repository}/pulls/#{@github.number}/reviews/#{review['id']}"
        Notes.stored(@github, path).filter_map do |comment|
          comment['id'] if comment['in_reply_to_id'].nil? && comment.dig('user', 'login') == @account &&
                           comment['body'].to_s.start_with?(Notes::MARKER)
        end
      end

      def threads
        @reader ||= PublicComments::Threads.new(@github)
        @threads ||= @reader.call.last
      end

      def unanswered?(thread)
        id = thread['thread_id']
        return false if @reader.truncated.include?(id) || @reader.anonymous.include?(id)

        @reader.authors[id] == [@account]
      end

      # Deletion cannot be undone, so the thread is read again right before it; only the moment between
      # this read and the deletion is left for a reply to land in.
      def still_alone?(thread_id)
        comments = @github.graphql(ALONE, id: thread_id).dig('node', 'comments')
        raise Error, "Note thread #{thread_id} is unavailable." unless comments.is_a?(Hash)

        comments['totalCount'] == 1 && comments['nodes']&.first&.dig('author', 'login') == @account
      end
    end
  end
end
