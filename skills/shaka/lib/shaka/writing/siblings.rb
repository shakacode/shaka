# frozen_string_literal: true

require_relative '../error'
require_relative 'duplication'

module Shaka
  module Writing
    # Reads the published counterpart a surface must not repeat. Neither renderer holds
    # both bodies, so each comparison fetches its sibling from the pull request itself.
    class Siblings
      def initialize(github)
        @github = github
      end

      def check_description(body)
        Duplication.new(body, linked_walkthrough(body)).check('description')
      end

      def check_walkthrough(body)
        Duplication.new(body, @github.managed_body).check('walkthrough')
      end

      private

      # Before the first walkthrough exists the description links no review, and a review
      # that cannot be read leaves the comparison unmade rather than blocking publication.
      def linked_walkthrough(body)
        prefix = Regexp.escape("https://github.com/#{@github.repository}/pull/#{@github.number}#pullrequestreview-")
        id = body[/#{prefix}(\d+)\b/, 1]
        return unless id

        @github.review(id)['body'].to_s
      rescue Error
        warn 'shaka: description duplication check skipped; the linked walkthrough could not be read.'
        nil
      end
    end
  end
end
