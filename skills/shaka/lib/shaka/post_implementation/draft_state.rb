# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Makes the checkpoint's PR a draft or marks it ready for review, only while it is open at the checkpoint
  # head, and confirms GitHub made the change.
  class PostImplementationDraftState
    DRAFT = <<~GRAPHQL
      mutation($id: ID!) {
        convertPullRequestToDraft(input: {pullRequestId: $id}) {
          pullRequest { id isDraft headRefOid }
        }
      }
    GRAPHQL
    READY = <<~GRAPHQL
      mutation($id: ID!) {
        markPullRequestReadyForReview(input: {pullRequestId: $id}) {
          pullRequest { id isDraft headRefOid }
        }
      }
    GRAPHQL
    CHANGES = {
      true => { mutation: DRAFT, key: 'convertPullRequestToDraft', action: 'draft conversion',
                failed: 'Draft conversion was not confirmed' },
      false => { mutation: READY, key: 'markPullRequestReadyForReview', action: 'it could be marked ready',
                 failed: 'Marking the PR ready was not confirmed' }
    }.freeze

    def initialize(github)
      @github = github
    end

    # Returns whether this call changed the PR; one already in the wanted state needs nothing.
    def change(head, draft:)
      change = CHANGES.fetch(draft)
      pull = @github.snapshot
      raise Error, "PR changed before #{change[:action]}; retry the checkpoint publication." unless
        pull.values_at('state', 'headRefOid') == ['OPEN', head]
      return false if pull['isDraft'] == draft

      changed = @github.graphql(change[:mutation], id: pull.fetch('id')).dig(change[:key], 'pullRequest')
      return true if changed && changed.values_at('id', 'isDraft', 'headRefOid') == [pull['id'], draft, head]

      raise Error, "#{change[:failed]} at the checkpoint head; inspect the PR before retrying."
    end
  end
end
