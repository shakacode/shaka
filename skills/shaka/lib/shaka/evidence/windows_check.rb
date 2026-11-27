# frozen_string_literal: true

require_relative '../executable_file'

module Shaka
  module Evidence
    # Starts a check on Windows, where Ruby refuses `pgroup`, and stops it without naming a process
    # that may not be the check any more.
    #
    # A job object holds the check and the descendants it starts, and ends them even after the leader
    # exits. Without a job, only the leader can be ended safely. Ruby keeps the handle of a child it
    # started until it reaps the child, and Process.kill ends a child through that handle, so the
    # child's ID cannot name another process until then. Ruby releases that handle inside wait2, also
    # when wait2 fails, and the waiter thread outlives that call, so the waiter records under a lock
    # that the handle may be gone and the stop reads that record under the same lock: it ends the
    # leader through the live handle, or leaves it alone. Either way it reports that descendants may
    # still be running.
    class WindowsCheck
      LIMITATION = 'no Windows job ended this check, so it or processes it started may still be running'
      # Seconds a stopped check gets to exit, and between checks for the leader's exit.
      STOP_SECONDS = 10
      POLL_SECONDS = 0.05

      attr_reader :pid, :output, :error, :waiter, :limitation

      # The job holds the leader before the waiter can reap it; AFTER_REAP lets a test hold the waiter
      # between releasing the handle and exiting.
      def initialize(command, root:, job: method(:adopt), after_reap: nil)
        @output, output = IO.pipe
        @error, error = IO.pipe
        @pid = Process.spawn(*command, chdir: root, in: File::NULL, out: output, err: error)
        @job = job.call(@pid)
        start_waiter(after_reap)
      rescue StandardError
        abandon_start
        raise
      ensure
        [output, error].each { |writer| writer&.close }
      end

      # Ends the check. Returns the limitation when descendants may outlive the stop. The wait is
      # bounded, so an interrupted helper still leaves when Windows refuses to end the leader.
      def stop
        ended = @job&.terminate
        @limitation = LIMITATION unless ended
        end_leader unless settled?(ended ? STOP_SECONDS : 0)
        settled?(STOP_SECONDS)
        @limitation
      end

      # A check that finished keeps whatever it left running, as on other platforms. An interrupted
      # one is ended with its job. An interrupt waits until both pipes are closed.
      def close(finished:)
        Thread.handle_interrupt(Object => :never) do
          finished ? @job&.close : @job&.terminate
          [@output, @error].each { |stream| stream.close unless stream.closed? }
        end
      end

      private

      def start_waiter(after_reap)
        @lock = Mutex.new
        @reaped = false
        @waiter = Thread.new { reap.tap { after_reap&.call } }
      end

      # A start that failed after spawning ends its job and its unreaped leader through Ruby's handle.
      def abandon_start
        [@output, @error].each { |reader| reader&.close }
        @job&.terminate
        return unless @pid && !@waiter

        quietly { Process.kill('KILL', @pid) }
        Process.detach(@pid)
      end

      # A leader the job already ended refuses the kill; detach reaps it whenever it exits, so a refused
      # kill cannot hold the start error.
      def quietly
        yield
      rescue SystemCallError
        nil
      end

      # A waiter that stopped on a failed wait has settled too.
      def settled?(seconds)
        !@waiter.join(seconds).nil?
      rescue SystemCallError
        true
      end

      def reap
        loop do
          status = @lock.synchronize { wait }
          return status if status

          sleep POLL_SECONDS
        end
      end

      # Called under the lock. A failed wait may also have released the handle.
      def wait
        Process.wait2(@pid, Process::WNOHANG)&.last.tap { |status| @reaped = true if status }
      rescue SystemCallError
        @reaped = true
        raise
      end

      # While unreaped under the lock, Process.kill uses the handle Ruby still holds. A refused kill
      # leaves the leader to finish, as on other platforms, and the limitation already says so.
      def end_leader
        @lock.synchronize { Process.kill('KILL', @pid) unless @reaped }
      rescue SystemCallError
        nil
      end

      # Without fiddle, which a later Ruby may not load under --disable-gems, there is no job.
      def adopt(pid)
        return unless ExecutableFile.windows?

        require_relative '../doctor/windows_job'
        Doctor::WindowsJob.adopt(pid)
      rescue LoadError
        nil
      end
    end
  end
end
