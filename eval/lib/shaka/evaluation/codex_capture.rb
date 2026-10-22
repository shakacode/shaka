# frozen_string_literal: true

require 'timeout'
require_relative 'codex_events'
require_relative 'codex_streams'

module Shaka
  module Evaluation
    # One operator-selected process; raw output stays outside the agent's workspace.
    class CodexCapture
      def initialize(environment:)
        valid = environment.is_a?(Hash) && environment.all? { |key, value| [key, value].all?(String) }
        raise ArgumentError, 'Expected explicit child environment' unless valid

        @environment = environment.dup.freeze
      end

      def run(command:, cwd:, directory:, seconds:, clock_id:)
        validate(command, seconds)
        @started = true
        @reader = CodexEvents.new(clock_id:)
        @deadline = now + seconds
        Dir.mkdir(directory, 0o700)
        CodexStreams.open(reader: @reader, directory:) { |streams| execute(command, File.realpath(cwd), streams) }
      end

      private

      def validate(command, seconds)
        valid = !@started && valid_command?(command) && valid_seconds?(seconds)
        raise ArgumentError, 'Expected one absolute command and a bounded deadline' unless valid
      end

      def valid_command?(command)
        command.is_a?(Array) && !command.empty? && command.all?(String) && command.first.start_with?('/')
      end

      def valid_seconds?(seconds)
        (seconds.is_a?(Integer) || seconds.is_a?(Float)) && seconds.finite? && seconds.positive? && seconds <= 3600
      end

      def execute(command, cwd, streams)
        @pipes = IO.pipe + IO.pipe
        spawn(command, cwd)
        @channels = { @pipes[0] => 0, @pipes[2] => 1 }
        timed_out = pump(streams)
        @reader.finish(exit_code: timed_out ? nil : @status.exitstatus).merge(
          'transport_status' => timed_out ? 'timed_out' : 'completed', 'exit_code' => @status&.exitstatus
        )
      ensure
        cleanup
      end

      def spawn(command, cwd)
        @pid = Process.spawn(@environment, *command, chdir: cwd, pgroup: true, unsetenv_others: true,
                                                     close_others: true, in: File::NULL, out: @pipes[1], err: @pipes[3])
        @pipes.values_at(1, 3).each(&:close)
      end

      def pump(streams)
        loop do
          observe_process
          return false if @status && @channels.empty?

          remaining = @deadline - now
          return true unless remaining.positive?

          ready(remaining).each { |io| consume(io, streams) }
        end
      end

      def ready(remaining) = IO.select(@channels.keys, nil, nil, [remaining, 0.05].min)&.first || []

      def observe_process
        @status ||= Process.waitpid2(@pid, Process::WNOHANG)&.last
        terminate if @status
      end

      def consume(io, streams)
        data = io.read_nonblock(16_384, exception: false)
        return if data == :wait_readable
        return streams.write(@channels.fetch(io), data) if data

        streams.eof(@channels.delete(io))
        io.close
      end

      def cleanup
        terminate if @pid
      ensure
        @pipes&.each { |io| io.close unless io.closed? }
      end

      def terminate
        return if @terminated

        signal('TERM')
        sleep 0.1
        @status ||= Process.waitpid2(@pid, Process::WNOHANG)&.last
        signal('KILL')
        Timeout.timeout(5) { Process.waitpid(@pid) } unless @status
        @terminated = true
      rescue Timeout::Error
        raise IOError, 'Owned Codex process could not be reaped'
      end

      def signal(name)
        Process.kill(name, -@pid)
      rescue Errno::ESRCH
        nil
      end

      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
