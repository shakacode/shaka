# frozen_string_literal: true

require_relative 'codex_capture'
require_relative 'driver_review'

module Shaka
  module Evaluation
    # Observe native heads and retain protected results; this does not accept terminal actions.
    class CodexDriver
      def initialize(plan, github:, environment:, verifier:, max_attempts:)
        @plan = plan.slice('repository', 'number', 'driver_actor', 'clock_id')
        @github = github
        @verifier = verifier
        @capture = CodexCapture.new(environment:)
        DriverReview.new(@plan.merge('head' => '0' * 40), github:, environment: verifier.fetch(:environment))
        raise ArgumentError, 'Expected a positive attempt bound' unless
          max_attempts.is_a?(Integer) && max_attempts.positive?

        @max_attempts = max_attempts
        @entries = []
      end

      def run(command:, cwd:, directory:, seconds:)
        valid = !@started && seconds.is_a?(Numeric) && seconds.finite? && seconds.positive? && seconds <= 3600
        raise ArgumentError, 'Expected one capture and bounded controller lifetime' unless valid

        start(directory, seconds)
        open_ledger do
          capture = @capture.run(command:, cwd:, directory: File.join(directory, 'capture'),
                                 seconds: remaining, clock_id: @plan.fetch('clock_id')) { observe(it) }
          raise IOError, 'Driver native capture incomplete' unless
            capture.values_at('transport_status', 'native_status', 'exit_code') == ['completed', 'completed', 0]

          { 'capture' => capture, 'verifications' => @entries }
        end
      end

      private

      def start(directory, seconds)
        @started = true
        @deadline = now + seconds
        @directory = directory
        Dir.mkdir(directory, 0o700)
      end

      def open_ledger
        path = File.join(@directory, 'ledger.jsonl')
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |ledger|
          @ledger = ledger
          yield
        end
      end

      def observe(observation)
        native = observation.fetch('native')
        checkpoint = native['type'] == 'turn.started' ||
                     (native['type'] == 'item.completed' && native.dig('item', 'type') == 'command_execution')
        return unless checkpoint

        head = current_head
        return if head == @last_head

        raise IOError, 'Driver attempt bound reached' if @entries.size >= @max_attempts

        verify(head, observation.fetch('ordinal'))
        @last_head = head
      end

      def current_head
        path = "repos/#{@plan.fetch('repository')}/pulls/#{@plan.fetch('number')}"
        pull = DeliveryReview.decode(api.get(path))
        head = pull.dig('head', 'sha')
        raise IOError, 'Observed PR head unavailable' unless valid_pull?(pull, head)

        remaining
        head
      rescue JSON::ParserError, NoMethodError, TypeError
        raise IOError, 'Observed PR head unavailable'
      end

      def valid_pull?(pull, head)
        pull.values_at('number', 'state', 'merged') == [@plan.fetch('number'), 'open', false] &&
          /\A[0-9a-f]{40}\z/.match?(head.to_s) && same_repository?(pull)
      end

      def same_repository?(pull)
        %w[head base].all? { |side| pull.dig(side, 'repo', 'full_name')&.casecmp?(@plan.fetch('repository')) }
      end

      def api = DeliveryGitHub.new(github: @github, seconds: [remaining, 30].min).start_deadline

      def verify(head, ordinal)
        attempt = @entries.size + 1
        started = attempt_record(head, ordinal, attempt)
        record(started)
        entry = run_verifier(head, attempt)
        remaining
        record('state' => 'completed', 'entry' => entry)
        @entries << entry
      rescue StandardError
        record(started.merge('state' => 'failed')) if started
        raise
      end

      def attempt_record(head, ordinal, attempt)
        { 'state' => 'started', 'head' => head, 'attempt' => attempt,
          'observation' => ordinal, 'clock_id' => @plan.fetch('clock_id'), 'at' => now }
      end

      def run_verifier(head, attempt)
        writer = DriverReview.new(@plan.merge('head' => head),
                                  github: @github,
                                  environment: @verifier.fetch(:environment), seconds: [remaining, 30].min)
        writer.run(command: @verifier.fetch(:command), cwd: @verifier.fetch(:cwd),
                   directory: File.join(@directory, "verification-#{attempt}"), attempt:, executions: attempt)
      end

      def record(row)
        @ledger.puts(JSON.generate(row))
        @ledger.flush
        @ledger.fsync
      end

      def remaining
        value = @deadline - now
        raise IOError, 'Driver controller deadline reached' unless value.positive?

        value
      end

      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
