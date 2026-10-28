# frozen_string_literal: true

require_relative 'codex_approval'
require_relative 'delivery_snapshot'
require_relative 'delivery_readback'

module Shaka
  module Evaluation
    # Assemble partial Ask evidence; complete activity inventory remains unavailable.
    class CodexAsk
      def initialize(plan, github:, seconds: 30, mechanics: false)
        @plan = plan
        @github = github
        @seconds = seconds
        @acceptor = CodexApproval.new(plan, mechanics:)
        @grader = DeliveryAsk.new(plan, mechanics:)
        DeliverySnapshot.new(plan, github:, seconds:) # Validate the declared native check App identities.
        raise ArgumentError, 'Check Apps must cover exactly the required names' unless
          plan.fetch('check_apps').keys.sort == plan.fetch('required_checks').sort
      end

      def collect(driver_result:, before:, walkthrough:)
        raise ArgumentError, 'Ask collector already used' if @started

        @started = true
        @deadline = now + @seconds
        acceptance = @acceptor.accept(driver_result:, walkthrough:, **before.slice('checks', 'changed_files')
                                                                          .transform_keys(&:to_sym))
        acceptance['current_walkthrough'] = reread(walkthrough)
        final = DeliverySnapshot.new(@plan, github: @github, seconds: remaining).read
        remaining
        assemble(driver_result, before, walkthrough, acceptance, final)
      end

      private

      def reread(receipt)
        row = receipt.fetch('review')
        reader = DeliveryReadback.new(**@plan.slice('repository', 'number', 'head').transform_keys(&:to_sym),
                                      github: @github, seconds: remaining)
        reader.read(node_id: row.fetch('id'), review_id: Integer(row.fetch('fullDatabaseId'), 10),
                    actor: @plan.fetch('machine_actor'))
      end

      def assemble(result, before, walkthrough, acceptance, final)
        raise IOError, 'Changed-file bounds differ' unless before.fetch('changed_files') == final.fetch('changed_files')

        packet = acceptance.merge(before.slice('checks', 'changed_files')).merge(
          'verifications' => result.fetch('verifications'), 'walkthrough' => walkthrough,
          'pull' => final.fetch('pull'),
          'command_capture_complete' => false, 'merge_attempts' => 'UNKNOWN'
        )
        { 'evidence' => packet, 'final_snapshot' => final, 'grading' => @grader.call(packet) }
      end

      def remaining
        value = @deadline - now
        raise IOError, 'Ask collection deadline reached' unless value.positive?

        value
      end

      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
