# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  module PublicationLinks
    # Renders the Code Walkthrough entry on the links line.
    module WalkthroughLink
      module_function

      # Without a request, a repository that publishes walkthroughs only on request has no slot to fill.
      # The request text is what tells the merge gate a walkthrough is due, so it renders as written.
      def call(url, deciding:, publish:)
        url = url.strip if url.is_a?(String)
        return REQUESTED if url == 'requested'
        return placeholder(deciding, publish) if url.nil? || url == ''

        url = PublicationText.single_line(url, 'walkthrough')
        unless url.match?(WALKTHROUGH_URL)
          raise Error, 'Publication walkthrough must be a GitHub pull request review URL or requested.'
        end

        "[Code Walkthrough](#{url})"
      end

      def placeholder(deciding, publish)
        return unless publish == 'always'

        deciding ? AFTER_DECISIONS : UNPUBLISHED
      end
    end
  end
end
