# frozen_string_literal: true

require_relative 'delivery_ask'

module Shaka
  module Evaluation
    # Accept one final native Ask request; this grants neither merge nor release authority.
    class CodexApproval
      def initialize(plan, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        raise ArgumentError, 'Expected controller clock' unless clock.respond_to?(:call)

        @clock = clock
        @plan = AskPlan.validate(plan)
        @grader = DeliveryAsk.new(@plan)
      end

      # Inputs must come directly from protected collectors in this controller clock lifetime.
      def accept(driver_result:, checks:, walkthrough:, changed_files:)
        raise ArgumentError, 'Approval acceptor already used' if @started

        @started = true
        packet = packet(driver_result, @clock.call, checks, walkthrough, changed_files)
        raise IOError, 'Approval prerequisites unavailable or premature' unless @grader.approval_ready?(packet)

        { 'clock_id' => @plan.fetch('clock_id'), 'terminal' => packet.fetch('terminal') }
      rescue KeyError, TypeError, NoMethodError
        raise IOError, 'Protected approval evidence unavailable'
      end

      private

      def packet(result, at, checks, walkthrough, changed_files)
        capture = result.fetch('capture')
        entries = result.fetch('verifications')
        raise IOError, 'Completed native capture unavailable' unless completed?(capture, at) && same_clock?(entries)

        { 'clock_id' => capture.fetch('clock_id'), 'terminal' => capture.fetch('terminal').merge('accepted_at' => at),
          'verifications' => entries, 'checks' => checks, 'walkthrough' => walkthrough,
          'changed_files' => changed_files }
      end

      def completed?(capture, at)
        capture.values_at('transport_status', 'native_status', 'exit_code', 'clock_id') ==
          ['completed', 'completed', 0, @plan.fetch('clock_id')] &&
          ordered?([capture.fetch('terminal').fetch('received_at'), capture.fetch('turn_ended_at'),
                    capture.fetch('observed_at'), at]) &&
          capture.fetch('terminal').fetch('native_item_id').is_a?(String)
      end

      def same_clock?(entries)
        !entries.empty? && entries.all? do |entry|
          entry.fetch('clock_id') == @plan.fetch('clock_id') &&
            entry.fetch('verification').fetch('clock_id') == @plan.fetch('clock_id')
        end
      end

      def ordered?(times)
        times.all? { |value| value.is_a?(Numeric) && value.finite? && value >= 0 } &&
          times.each_cons(2).all? { |earlier, later| earlier <= later }
      end
    end
  end
end
