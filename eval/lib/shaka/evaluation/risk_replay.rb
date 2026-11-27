# frozen_string_literal: true

require_relative '../../../../skills/shaka/lib/shaka/post_implementation_report'
require_relative 'review_replay'

module Shaka
  module Evaluation
    # Reruns the checkpoint on historical heads to compare risk ratings, reusing the review replay's fixture,
    # isolation, budget and private records. Nothing reaches GitHub, so past labels and merge state stay unchanged.
    class RiskReplay < ReviewReplay
      CASES = File.expand_path('../../../risk-replay', __dir__)

      private

      # Repeats measure whether one setting rates the same change the same way twice. Shifting the index
      # alternates which arm goes first on each repeat, as the reviewer replay alternates it by case.
      def replay_pair(row, index)
        @options.fetch(:repeat, 1).times { |repeat| super(row, index + repeat) }
      end

      def completed?(result, row)
        super && PostImplementationReport::RISK.include?(result.dig('risk', 'rating'))
      end

      # The packet is the description content the original checkpoint read, frozen without later review results.
      def review_arguments(row, arm, root, snapshot)
        chosen = @options.fetch(arm)
        arguments = ['post-implementation', 'run', '--root', root, '--base', row.fetch('base'),
                     '--head', row.fetch('head'), '--reviewer', @reviewer, '--ref', snapshot,
                     '--content-file', File.join(CASES, row.fetch('packet')), '--timeout-seconds', '300',
                     '--model', chosen.fetch(:model)]
        arguments.push('--effort', @options.fetch(:effort)) if @options[:effort]
        arguments
      end
    end
  end
end
