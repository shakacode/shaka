# frozen_string_literal: true

require_relative '../../../../skills/shaka/lib/shaka/post_implementation_report'
require 'digest'
require 'securerandom'
require_relative 'review_replay'
require_relative 'risk_replay_inputs'

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

      # Every record names its whole comparison, down to the invocation and the case file it read, so the scorer
      # can refuse to pool two runs, count the runs a stop prevented, and refuse a case file that has changed since.
      def initialize(options)
        super
        @comparison = { invocation: SecureRandom.uuid, reviewer: @reviewer, effort: options[:effort],
                        repeats: options.fetch(:repeat, 1), case_file: Digest::SHA256.file(CASE_FILE).hexdigest,
                        arms: options.slice(:baseline, :candidate) }
      end

      # Each arm reads the packet copy taken here, so an edit to a packet mid-run cannot reach one arm only;
      # the digests let the scorer refuse a packet that has changed since.
      def run(rows)
        same_policy!
        @comparison[:tools] = RiskReplayInputs.tools(@helper, @host)
        @comparison[:cases] = rows.map { |row| row.fetch('id') }
        @packets = rows.to_h { |row| [row.fetch('id'), File.binread(File.join(CASES, row.fetch('packet')))] }
        @comparison[:packets] = @packets.transform_values { |bytes| Digest::SHA256.hexdigest(bytes) }
        super
      end

      private

      # Checked before any sign-in or spend, and recorded, so the scorer applies the same policy the arms ran under.
      def same_policy!
        policies = @comparison.fetch(:arms).values.map { |arm| RiskReplayInputs.policy(@source, arm.fetch(:criteria)) }
        return @comparison[:policy] = policies.first if policies.uniq.one?

        raise ArgumentError,
              'The arms apply different risk areas or thresholds; keep them the same in both settings commits'
      end

      # A disabled checkpoint launches no reviewer, so it spent nothing; the replay still stops on its missing rating.
      def usage_for(result)
        return { 'cache_neutral_dollars' => 0, 'billed_dollars' => 0 } if result['status'] == 'opted_out'

        super
      end

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

      # The packet is reconstructed from the PR description, without later review results.
      def review_arguments(row, arm, root, snapshot)
        packet = File.join(File.dirname(root), "#{row.fetch('id')}.packet.json")
        File.binwrite(packet, @packets.fetch(row.fetch('id')))
        chosen = @options.fetch(arm)
        arguments = ['post-implementation', 'run', '--root', root, '--base', row.fetch('base'),
                     '--head', row.fetch('head'), '--reviewer', @reviewer, '--ref', snapshot,
                     '--content-file', packet, '--timeout-seconds', '300',
                     '--model', chosen.fetch(:model)]
        arguments.push('--effort', @options.fetch(:effort)) if @options[:effort]
        arguments
      end
    end
  end
end
