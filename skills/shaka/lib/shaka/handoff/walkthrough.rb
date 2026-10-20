# frozen_string_literal: true

require_relative '../decision_labels'
require_relative '../public_comments/bounded_list'
require_relative '../publication/publishing'
require_relative '../walkthrough/history'

module Shaka
  # Adds the walkthrough fact to the handoff report.
  class Handoff
    # Finds the commit the current walkthrough explains, counting only evidence this account controls.
    class Walkthrough
      def initialize(github)
        @github = github
      end

      # Superseded walkthroughs are wrapped in a pointer, so only the current one still renders as a
      # walkthrough. Only this account's reviews count, so a commenter's copy cannot change what is owed.
      def revision
        account = @github.api('user')['login']
        current = reviews.reverse.find do |review|
          review.dig('user', 'login') == account && review['state'] == 'COMMENTED' &&
            WalkthroughText.rendered?(review['body'].to_s)
        end
        current && bound_revision(current)
      end

      private

      def reviews
        path = "repos/#{@github.repository}/pulls/#{@github.number}/reviews"
        PublicComments::BoundedList.new(@github, max_pages: 5, label: 'Review listing').call(path)
      end

      # GitHub binds a review to its commit; the footer is editable text, so it only counts when it agrees.
      def bound_revision(review)
        commit = review['commit_id']
        commit if commit.is_a?(String) && WalkthroughText.revision(review['body']) == commit
      end
    end

    # Reports whether the walkthrough explains the live head, and whether a missing or older one is owed.
    module WalkthroughFact
      private

      def walkthrough_fact(live)
        revision = Walkthrough.new(@github).revision
        unless revision
          return owe('no walkthrough', 'Publish a walkthrough before asking for merge.') if merge_requested?

          return note('no walkthrough', 'No walkthrough yet; one is required before merge.')
        end
        return "walkthrough #{revision[0, SHORT]}" if revision == live

        fact = "walkthrough #{revision[0, SHORT]}"
        return note(fact, "The walkthrough explains #{revision}; publish one after the decisions.") if deciding?

        owe(fact, "The walkthrough explains #{revision}; publish one for #{live}.")
      end

      # An answer may change the code, so the next walkthrough waits for it; a merge request never does.
      # `attention --state answer` can set the label alone, so the description must list the decisions too.
      def deciding?
        return false if merge_requested? || @labels.none? { |label| label.casecmp?('awaiting-answer') }

        body = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")['body'].to_s
        DecisionLabels.asks_for_decisions?(Publishing.managed_region(body.gsub("\r\n", "\n")).to_s)
      end
    end

    include WalkthroughFact
  end
end
