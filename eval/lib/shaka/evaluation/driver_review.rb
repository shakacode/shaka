# frozen_string_literal: true

require_relative 'delivery_readback'
require_relative 'protected_verification'

module Shaka
  module Evaluation
    # One protected verification attempt and a COMMENT receipt, never an approval or merge.
    class DriverReview
      def initialize(plan, github:, environment:, seconds: 30)
        @plan = plan.slice('repository', 'number', 'head', 'driver_actor', 'clock_id')
        @github = github
        @transport = DeliveryGitHub.new(github:, seconds:)
        reader(seconds) # Reuse the readback's pinned PR identity validation before I/O.
        raise ArgumentError, 'Expected driver actor and controller clock lifetime' unless
          @plan.values_at('driver_actor', 'clock_id').all? { |value| value.is_a?(String) && !value.strip.empty? }

        @verifier = ProtectedVerification.new(environment: environment.merge('SHAKA_EVAL_HEAD' => @plan.fetch('head')))
      end

      def run(command:, cwd:, directory:, attempt:, executions:)
        validate_attempt(attempt, executions)
        @started = true
        @api = @transport.start_deadline
        current_head!
        verification = @verifier.run(command:, cwd:, directory:, seconds: @api.seconds_left,
                                     clock_id: @plan.fetch('clock_id'))
        current_head!
        publish(verification, attempt, executions)
      end

      private

      def validate_attempt(attempt, executions)
        valid = !@started && attempt.is_a?(Integer) && attempt.positive? &&
                executions.is_a?(Integer) && executions >= attempt
        raise ArgumentError, 'Expected one attempt and cumulative verifier execution count' unless valid
      end

      def current_head!
        pull = decode(@api.get("repos/#{@plan.fetch('repository')}/pulls/#{@plan.fetch('number')}"))
        valid = pull.values_at('number', 'state', 'merged') == [@plan.fetch('number'), 'open', false] &&
                pull.dig('head', 'sha') == @plan.fetch('head') && same_repository?(pull)
        raise IOError, 'Driver verification PR head unavailable' unless valid
      rescue NoMethodError, TypeError
        raise IOError, 'Driver verification PR head unavailable'
      end

      def same_repository?(pull)
        %w[head base].all? do |side|
          pull.dig(side, 'repo', 'full_name')&.casecmp?(@plan.fetch('repository'))
        end
      end

      def publish(verification, attempt, executions)
        body = body(verification.fetch('exit_code'), attempt, executions)
        path = "repos/#{@plan.fetch('repository')}/pulls/#{@plan.fetch('number')}/reviews"
        posted = @api.post(path, { 'event' => 'COMMENT', 'commit_id' => @plan.fetch('head'), 'body' => body })
        completed = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        receipt = read_post(posted, body)
        { 'head' => @plan.fetch('head'), 'clock_id' => @plan.fetch('clock_id'), 'attempt' => attempt,
          'executions' => executions, 'verification' => verification, 'post_completed_at' => completed,
          'receipt' => receipt }
      end

      def read_post(bytes, body)
        posted = decode(bytes)
        receipt = reader(@api.seconds_left).read(node_id: posted.fetch('node_id'), review_id: posted.fetch('id'),
                                                 actor: @plan.fetch('driver_actor'))
        @api.seconds_left
        raise IOError, 'Posted driver review differs' unless receipt.dig('review', 'body') == body

        receipt
      rescue KeyError, TypeError, NoMethodError, ArgumentError
        raise IOError, 'Posted driver review unavailable'
      end

      def reader(seconds)
        options = @plan.slice('repository', 'number', 'head').transform_keys(&:to_sym)
        DeliveryReadback.new(**options, github: @github, seconds:)
      end

      def body(exit_code, attempt, executions)
        result = exit_code&.zero? ? 'PASS' : 'FAIL'
        "🤖 Shaka evaluation driver · scripted · UNKNOWN · UNKNOWN\n\n" \
          "Scripted evaluation fixture; this reports a protected check, not code-review quality.\n\n" \
          "driver-verification: #{result} head=#{@plan.fetch('head')} attempt=#{attempt} executions=#{executions}"
      end

      def decode(bytes)
        DeliveryReview.decode(bytes)
      rescue JSON::ParserError
        raise IOError, 'Driver GitHub response unavailable'
      end
    end
  end
end
