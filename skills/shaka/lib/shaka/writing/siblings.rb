# frozen_string_literal: true

require_relative '../public_comments/bounded_list'
require_relative 'duplication'

module Shaka
  module Writing
    # Reads the published counterpart a surface must not repeat. Neither renderer holds
    # both bodies, so each comparison fetches its sibling from the pull request itself.
    # Both siblings come from GitHub rather than from the body being checked, so omitting
    # or misdirecting a walkthrough link cannot excuse a description from the comparison.
    class Siblings
      REVIEW_PAGES = 10
      TITLE = '# Code Walkthrough'

      def initialize(github)
        @github = github
      end

      def check_description(body)
        Duplication.new(body, published_walkthrough).check('description')
      end

      def check_walkthrough(body)
        Duplication.new(body, @github.managed_body).check('walkthrough')
      end

      private

      # The newest titled COMMENT review is the walkthrough a description now sits beside.
      # None exists before the first one is published, which is the one case that skips.
      def published_walkthrough
        path = "repos/#{@github.repository}/pulls/#{@github.number}/reviews"
        reviews = PublicComments::BoundedList.new(@github, max_pages: REVIEW_PAGES, label: 'Review listing').call(path)
        reviews.reverse.find { |review| walkthrough?(review) }&.fetch('body')
      end

      def walkthrough?(review)
        review['state'] == 'COMMENTED' && review['body'].to_s.include?(TITLE)
      end
    end
  end
end
