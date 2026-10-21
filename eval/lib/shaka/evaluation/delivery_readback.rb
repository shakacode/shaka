# frozen_string_literal: true

require_relative 'delivery_github'
require_relative 'delivery_review'

module Shaka
  module Evaluation
    # Run on the protected driver, with its own GitHub credentials; never mount receipts in the agent.
    class DeliveryReadback
      def initialize(repository:, number:, head:, github:, seconds: 30)
        unless valid_identity?(repository, number, head) && seconds.is_a?(Numeric) && seconds.positive? && seconds <= 30
          raise ArgumentError, 'Expected a pinned delivery PR and bounded read deadline'
        end

        @expected = { 'repository' => repository, 'number' => number, 'head' => head }
        @api = DeliveryGitHub.new(github:, seconds:)
      end

      def read(node_id:, review_id:, actor:)
        valid = [node_id, actor].all? { |value| value.is_a?(String) && !value.strip.empty? } &&
                review_id.is_a?(Integer) && review_id.positive?
        raise ArgumentError, 'Expected native review IDs and the declared actor' unless valid

        expected = @expected.merge('node_id' => node_id, 'review_id' => review_id.to_s, 'actor' => actor)
        row = DeliveryReview.read(@api.graphql(DeliveryReview::QUERY, { 'id' => node_id }), expected)
        { 'review' => row, 'readback_finished_at' => Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end

      def unchanged?(receipt)
        row = receipt.fetch('review')
        current = read(node_id: row.fetch('id'), review_id: Integer(row.fetch('fullDatabaseId'), 10),
                       actor: row.fetch('author').fetch('login'))
        current.fetch('review') == row
      rescue IOError
        false
      end

      private

      def valid_identity?(repository, number, head)
        repository.is_a?(String) && %r{\A[\w-]+/[\w.-]+\z}.match?(repository) &&
          number.is_a?(Integer) && number.positive? && /\A[0-9a-f]{40}\z/.match?(head.to_s)
      end
    end
  end
end
