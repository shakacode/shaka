# frozen_string_literal: true

require_relative '../error'
require_relative '../walkthrough/notes'

module Shaka
  # Posts a walkthrough review with its inline notes and confirms GitHub kept every note.
  module WalkthroughNotePosting
    private

    # GitHub refuses the whole review when one note's lines are outside the diff, so nothing is posted.
    def create_walkthrough(head, body, notes)
      fields = { event: 'COMMENT', commit_id: head, body: body }
      return api(reviews_path, method: 'POST', fields:) if notes.empty?

      api(reviews_path, method: 'POST', fields: fields.merge(comments: notes))
    rescue Error => e
      raise e if notes.empty?

      raise Error, "#{e.message} GitHub refuses the whole review when a note sits on lines the diff " \
                   "does not show; check #{notes.map { |note| Walkthrough::Notes.location(note) }.join(', ')}."
    end

    def verify_notes(id, notes)
      return if notes.empty?

      stored = api_list("#{reviews_path}/#{id}/comments?per_page=100").map { |note| note.values_at('path', 'body') }
      return if stored.sort == notes.map { |note| note.values_at('path', 'body') }.sort

      raise Error, "Published walkthrough review #{id} did not keep its #{notes.size} notes."
    end
  end
end
