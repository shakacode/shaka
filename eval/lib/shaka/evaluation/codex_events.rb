# frozen_string_literal: true

require 'digest'
require 'json'
require_relative 'codex_event_state'

module Shaka
  module Evaluation
    # Private observations from one protected native stdout stream, not execution qualification.
    class CodexEvents
      MAX_LINE = 1_048_576
      MAX_BYTES = 64 * MAX_LINE
      MAX_EVENTS = 100_000

      def initialize(clock_id:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        raise ArgumentError, 'Expected a controller clock lifetime and clock' unless
          clock_id.is_a?(String) && !clock_id.strip.empty? && clock.respond_to?(:call)

        @clock_id = clock_id
        @clock = clock
        @events = []
        @bytes = 0
        @digest = Digest::SHA256.new
        @state = CodexEventState.new
      end

      def receive(line)
        unavailable if @sealed || @invalid
        event = parse(line)
        observation = { 'ordinal' => @events.size + 1, 'received_at' => timestamp, 'native' => event }
        @state.receive(observation)
        retain(observation, line)
        nil
      rescue JSON::ParserError, KeyError, TypeError, NoMethodError, ArgumentError, IOError
        @invalid = true
        unavailable
      end

      # The controller calls this only after stdout EOF and reaping its owned process.
      def finish(exit_code:)
        unavailable if @sealed || @invalid || !(exit_code.nil? || exit_code.is_a?(Integer))
        @sealed = true
        @state.result(exit_code).merge(
          'clock_id' => @clock_id, 'events' => @events, 'byte_count' => @bytes,
          'stream_digest' => "sha256:#{@digest.hexdigest}", 'observed_at' => timestamp,
          'command_capture_complete' => false
        )
      rescue KeyError, TypeError, NoMethodError, ArgumentError, IOError
        @invalid = true
        unavailable
      end

      private

      def parse(line)
        unavailable unless line.is_a?(String) && within_bounds?(line) && line?(line)
        event = JSON.parse(line, allow_duplicate_key: false)
        unavailable unless event.is_a?(Hash)
        event
      end

      def timestamp
        value = @clock.call
        unavailable unless value.is_a?(Numeric) && value.finite? && value >= 0 &&
                           (@previous.nil? || value >= @previous)
        @previous = value
      rescue StandardError
        @invalid = true
        unavailable
      end

      def line?(line) = line.valid_encoding? && line.lines.one?

      def within_bounds?(line)
        line.bytesize <= MAX_LINE && @bytes + line.bytesize <= MAX_BYTES && @events.size < MAX_EVENTS
      end

      def retain(observation, line)
        @events << observation
        @bytes += line.bytesize
        @digest << line
      end

      def unavailable = raise(IOError, 'Native Codex event stream unavailable')
    end
  end
end
