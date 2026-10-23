# frozen_string_literal: true

require 'digest'
require 'io/wait'
require 'timeout'

module Shaka
  module Evaluation
    # Runs only the controller's fixed command; native event text is never executable input.
    class ProtectedVerification
      MAX_BYTES = 1_048_576

      def initialize(environment:)
        valid = environment.is_a?(Hash) && environment.all? { |key, value| [key, value].all?(String) }
        raise ArgumentError, 'Expected explicit verifier environment' unless valid

        @environment = environment.dup.freeze
      end

      def run(command:, cwd:, directory:, seconds:, clock_id:)
        validate(command, seconds, clock_id)
        prepare(seconds)
        Dir.mkdir(directory, 0o700)
        File.open(File.join(directory, 'output.log'), 'wx', 0o600) do |log|
          execute(command, File.realpath(cwd), log)
        end
        result(clock_id)
      ensure
        cleanup
      end

      private

      def prepare(seconds)
        @started_at = now
        @deadline = @started_at + seconds
        @digest = Digest::SHA256.new
        @bytes = 0
      end

      def result(clock_id)
        { 'clock_id' => clock_id, 'started_at' => @started_at, 'finished_at' => now,
          'exit_code' => @status.exitstatus, 'byte_count' => @bytes, 'output_digest' => "sha256:#{@digest.hexdigest}" }
      end

      def validate(command, seconds, clock_id)
        valid = !@started_at && valid_command?(command) && valid_seconds?(seconds) &&
                clock_id.is_a?(String) && !clock_id.strip.empty?
        raise ArgumentError, 'Expected one fixed verifier command, clock lifetime and bounded deadline' unless valid
      end

      def valid_command?(command)
        command.is_a?(Array) && !command.empty? && command.all?(String) && command.first.start_with?('/')
      end

      def valid_seconds?(seconds)
        seconds.is_a?(Numeric) && seconds.finite? && seconds.positive? && seconds <= 30
      end

      def execute(command, cwd, log)
        @input, @output = IO.pipe
        @pid = Process.spawn(@environment, [command.first, command.first], *command.drop(1),
                             chdir: cwd, pgroup: true, unsetenv_others: true, close_others: true,
                             in: File::NULL, out: @output, err: @output)
        @output.close
        pump(log)
      end

      def pump(log)
        loop do
          terminate if status
          remaining = @deadline - now
          raise IOError, 'Protected verification deadline exceeded' unless remaining.positive?
          break if @eof && @status

          consume(log) if readable?(remaining)
        end
      end

      def readable?(remaining)
        return @input.wait_readable([remaining, 0.05].min) unless @eof

        sleep [remaining, 0.01].min
        false
      end

      def consume(log)
        bytes = @input.read_nonblock(16_384, exception: false)
        return if bytes == :wait_readable
        return @eof = true unless bytes

        raise IOError, 'Protected verification output exceeded bound' if @bytes + bytes.bytesize > MAX_BYTES

        log.write(bytes)
        @digest << bytes
        @bytes += bytes.bytesize
      end

      def status = @status ||= Process.waitpid2(@pid, Process::WNOHANG)&.last

      def cleanup
        terminate if @pid
      ensure
        [@input, @output].compact.each { |io| io.close unless io.closed? }
      end

      def terminate
        return if @terminated

        status
        signal('TERM')
        sleep 0.1
        status
        signal('KILL')
        Timeout.timeout(5) { @status = Process.waitpid2(@pid).last } unless @status
        @terminated = true
      rescue Timeout::Error
        raise IOError, 'Owned verifier process could not be reaped'
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
