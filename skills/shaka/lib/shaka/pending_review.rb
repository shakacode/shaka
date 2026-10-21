# frozen_string_literal: true

module Shaka
  # Finds a review this account started on GitHub and has not submitted. GitHub shows it only to its
  # author and allows one per person on a pull request, so it holds back the walkthrough review.
  module PendingReview
    MESSAGE = 'You have unsubmitted review comments on this PR. Submit or discard them so the agent can ' \
              'post its walkthrough and act on them.'

    def self.find(reviews, login)
      reviews.find { |review| review['state'] == 'PENDING' && review.dig('user', 'login') == login }
    end
  end
end
