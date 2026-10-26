# frozen_string_literal: true

module Shaka
  class ReviewThread
    # GitHub's resolve mutation. Walkthrough note cleanup loads only this, because the reply
    # check reads agent posts, and those read the walkthrough history that loads the cleanup.
    MUTATION = <<~GRAPHQL
      mutation($id: ID!) {
        resolveReviewThread(input: { threadId: $id }) {
          thread { id isResolved }
        }
      }
    GRAPHQL
  end
end
