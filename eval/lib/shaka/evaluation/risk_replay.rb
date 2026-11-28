# frozen_string_literal: true

require_relative '../../../../skills/shaka/lib/shaka/post_implementation_report'
require_relative 'review_replay'

module Shaka
  module Evaluation
    # Reruns the checkpoint on historical heads to compare risk ratings, reusing the review replay's fixture,
    # isolation, budget and private records. Nothing reaches GitHub, so past labels and merge state stay unchanged.
    class RiskReplay < ReviewReplay
      CASES = File.expand_path('../../../risk-replay', __dir__)
      # The case version both the replay and the scorer read; a new version changes only this name.
      CASE_FILE = File.join(CASES, 'v1.jsonl')

      # The parser fills in this rating when a report omits one, so it marks a missing rating, not a judgment.
      def self.rated?(result)
        risk = result['risk']
        PostImplementationReport::RISK.include?(risk&.dig('rating')) && risk != PostImplementationReport::LEGACY_RISK
      end

      # Every record names its whole comparison, so the scorer can refuse to pool two and count missing runs.
      def initialize(options)
        super
        @comparison = { reviewer: @reviewer, effort: options[:effort], repeats: options.fetch(:repeat, 1) }
      end

      def run(rows)
        @comparison[:cases] = rows.map { |row| row.fetch('id') }
        super
      end

      private

      # Repeats measure whether one setting rates the same change the same way twice. Shifting the index
      # alternates which arm goes first on each repeat, as the reviewer replay alternates it by case.
      def replay_pair(row, index)
        @comparison.fetch(:repeats).times do |repeat|
          @repeat = repeat
          super(row, index + repeat)
        end
      end

      def completed?(result, row) = super && self.class.rated?(result)

      def save_run(id, case_id, arm, record)
        super(id, case_id, arm, record.merge('comparison' => @comparison, 'repeat' => @repeat))
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
