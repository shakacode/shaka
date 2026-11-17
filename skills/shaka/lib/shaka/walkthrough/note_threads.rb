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

        index = fresh_threads
        roots.select { |id| index[id] && unanswered?(index[id]) }.each do |id|
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

      # Read just before deleting, per review, so a reply that arrives during publication is seen. Deletion
      # cannot be undone, so a reply posted in the seconds between this read and the deletion is the remaining gap.
      def fresh_threads
        @reader = PublicComments::Threads.new(@github)
        @reader.call.last
      end

      def unanswered?(thread)
        id = thread['thread_id']
        return false if @reader.truncated.include?(id) || @reader.anonymous.include?(id)

        @reader.authors[id] == [@account]
      end
    end
  end
end
