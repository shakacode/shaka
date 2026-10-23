# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'

module Shaka
  module Evaluation
    # Bounded GitHub transport for protected delivery readers and the fixture review writer.
    class DeliveryGitHub
      def initialize(github:, seconds: 30, deadline: nil)
        unless valid_transport?(github, seconds)
          raise ArgumentError, 'Expected an absolute GitHub CLI and a bounded read deadline'
        end

        @gh = File.realpath(github)
        @seconds = seconds
        @deadline = deadline
        raise ArgumentError, 'Expected a finite monotonic deadline' unless valid_deadline?(deadline)
      end

      def start_deadline
        self.class.new(github: @gh, seconds: @seconds,
                       deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + @seconds)
      end

      def seconds_left
        return @seconds unless @deadline

        remaining = @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise IOError, 'Delivery GitHub read unavailable' unless remaining.positive?

        [remaining, @seconds].min
      end

      def graphql(query, variables)
        capture(['graphql', '--input', '-'], JSON.generate({ 'query' => query, 'variables' => variables }))
      end

      def get(path) = capture(['--method', 'GET', path], '')

      def post(path, request) = capture(['--method', 'POST', path, '--input', '-'], JSON.generate(request))

      private

      def valid_transport?(github, seconds)
        github.is_a?(String) && github.start_with?('/') && seconds.is_a?(Numeric) &&
          seconds.finite? && seconds.positive? && seconds <= 30
      end

      def valid_deadline?(deadline)
        deadline.nil? || (deadline.is_a?(Numeric) && deadline.finite?)
      end

      def capture(arguments, request)
        seconds_left
        argv = [@gh, 'api', '--hostname', 'github.com', *arguments]
        Open3.popen3({ 'GH_PROMPT_DISABLED' => '1' }, *argv, pgroup: true) do |input, stdout, stderr, process|
          read_process(input, stdout, stderr, process, request)
        end
      rescue SystemCallError, Timeout::Error
        raise IOError, 'Delivery GitHub read unavailable'
      end

      def read_process(input, stdout, stderr, process, request)
        errors = Thread.new { IO.copy_stream(stderr, File::NULL) }
        Timeout.timeout(seconds_left) { answer(input, stdout, process, request) }
      ensure
        terminate(process.pid)
        errors&.join
      end

      def answer(input, stdout, process, request)
        input.write(request)
        input.close
        bytes = stdout.read(1_048_577).to_s
        raise IOError, 'Delivery GitHub read unavailable' if bytes.bytesize > 1_048_576 || !process.value.success?

        bytes
      end

      def terminate(pid)
        Process.kill('KILL', -pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
