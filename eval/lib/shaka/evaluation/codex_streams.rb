# frozen_string_literal: true

require_relative 'codex_events'

module Shaka
  module Evaluation
    # Bounded private stdout/stderr retention and JSONL framing, never shell parsing.
    class CodexStreams
      LIMITS = [CodexEvents::MAX_BYTES, 8 * 1_048_576].freeze

      def self.open(reader:, directory:)
        File.open(File.join(directory, 'stdout.jsonl'), 'wx', 0o600) do |output|
          File.open(File.join(directory, 'stderr.log'), 'wx', 0o600) do |errors|
            yield new(reader:, logs: [output.binmode, errors.binmode])
          end
        end
      end

      def initialize(reader:, logs:)
        @reader = reader
        @logs = logs
        @bytes = [0, 0]
        @pending = +''.b
      end

      def write(kind, data)
        @bytes[kind] += data.bytesize
        raise IOError, 'Native Codex stream limit exceeded' if @bytes[kind] > LIMITS.fetch(kind)

        @logs.fetch(kind).write(data)
        return unless kind.zero?

        @pending << data
        lines
        raise IOError, 'Native Codex line limit exceeded' if @pending.bytesize > CodexEvents::MAX_LINE
      end

      def eof(kind)
        return unless kind.zero? && !@pending.empty?

        @reader.receive(@pending.force_encoding(Encoding::UTF_8))
        @pending.clear
      end

      private

      def lines
        while (boundary = @pending.index("\n"))
          line = @pending.slice!(0, boundary + 1).force_encoding(Encoding::UTF_8)
          @reader.receive(line)
        end
      end
    end
  end
end
