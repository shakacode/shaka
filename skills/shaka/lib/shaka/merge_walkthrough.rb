# frozen_string_literal: true

require_relative 'error'
require_relative 'walkthrough/history'

module Shaka
  # A walkthrough is optional until one is due. A named one must be the walkthrough this account
  # published for this head, so reviewer notes or another account's comment cannot stand in for it.
  class MergeWalkthrough
    # due is a WalkthroughDue, or nil when nothing makes one due.
    def initialize(github, due)
      @github = github
      @due = due
    end

    def verify!(id, head)
      return missing! if id.nil?

      review = @github.review(id)
      unless review.is_a?(Hash) && review['id'].to_s == id.to_s && review['commit_id'] == head
        raise Error, 'Walkthrough must identify a review on this PR at the expected head'
      end
      return if published?(review, head)

      raise Error, "Walkthrough must be this account's submitted walkthrough for the expected head"
    end

    private

    def missing!
      return unless @due&.due?

      raise Error, 'A walkthrough is due for this PR; publish it for this head and pass --walkthrough'
    end

    def published?(review, head)
      body = review['body'].to_s
      review['state'] == 'COMMENTED' && review.dig('user', 'login') == @github.viewer_login &&
        WalkthroughText.rendered?(body) && WalkthroughText.revision(body) == head
    end
  end
end
