# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative '../executable_file'
require_relative '../local_review/process'
require_relative 'candidate_tree'

module Shaka
  module Evidence
    # Runs a check in its own process group and recaptures the candidate tree while it runs.
    # An edit to the checkout voids the result anyway, so the check stops within one interval
    # plus a capture instead of finishing first. Only the check's own group is signaled.
    # An edit undone before the next capture is not seen, as the comparison after the check
    # never saw one either.
    class TreeWatch
      MESSAGE = 'worktree changed mid-run'
      # Seconds between captures. One capture took about 2 seconds on this repository under heavy
      # load, so an edit stops the check well within a minute.
      DEFAULT_INTERVAL = 15
      # Seconds a stopped Windows check gets to exit.
      STOP_SECONDS = 10
      Outcome = Data.define(:status, :changed_tree) do
        def stopped? = !changed_tree.nil?

        # Result fields that say why the check did not finish.
        def stop_fields = stopped? ? { 'stop_reason' => MESSAGE } : {}
      end

      class << self
        attr_accessor :interval
      end
      self.interval = DEFAULT_INTERVAL

      def initialize(command, root:, tree:, interval: self.class.interval, windows: ExecutableFile.windows?)
        @command = command
        @root = root
        @tree = tree
        @interval = interval
        @windows = windows
      end

      # Writes the check's output and then its errors to standard error once it ends.
      def run
        Open3.popen3(*@command, chdir: @root, **group) do |input, output, error, waiter|
          input.close
          @job = adopt(waiter.pid)
          outcome(waiter, [output, error].map { |stream| Thread.new { stream.read } })
        ensure
          # An interrupted helper would otherwise leave the check running in its separate group.
          stop(waiter) if waiter&.alive?
          @job&.close
        end
      end

      private

      def outcome(waiter, readers)
        changed = watch(waiter, readers)
        $stderr.write(*(changed ? drain(readers) : readers.map(&:value)))
        Outcome.new(status: waiter.value, changed_tree: changed)
      end

      # A descendant can hold the output open after the leader exits, so the watch lasts until
      # the output closes too.
      def watch(waiter, readers)
        until LocalReviewProcess.join_before_deadline([waiter, *readers], clock + @interval)
          current = capture
          return stop(waiter, current) if current && current != @tree
        end
        nil
      end

      # A file can vanish while Git stages it, or the capture can fail. The next capture, or the
      # comparison after the check, decides instead.
      def capture
        CandidateTree.capture(root: @root)
      rescue Error, SystemCallError
        nil
      end

      def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # TERM, then KILL for members that outlive their leader. A lasting macOS denial of the KILL
      # leaves the result to report the stop anyway.
      def stop(waiter, tree = nil)
        warn "shaka: #{MESSAGE}; stopping the check" if tree
        @windows ? end_tree(waiter) : LocalReviewProcess.terminate(waiter)
        tree
      rescue Errno::EPERM
        tree
      end

      # A descendant that left the group can keep a pipe open after the stop, so a stopped
      # check's output is whatever arrived shortly after it.
      def drain(readers) = readers.map { |reader| LocalReviewProcess.thread_output(reader) }

      # Windows Ruby refuses `pgroup`. There a job object holds the check and the descendants it
      # starts, and still names them after the leader exits, which taskkill /T cannot.
      def group = @windows ? {} : { pgroup: true }

      def adopt(pid)
        return unless @windows && ExecutableFile.windows?

        require_relative '../doctor/windows_job'
        Doctor::WindowsJob.adopt(pid)
      end

      # taskkill covers a check the job could not hold. A check that outlives both is left to
      # finish rather than hang the helper.
      def end_tree(waiter)
        @job&.terminate
        system('taskkill.exe', '/F', '/T', '/PID', waiter.pid.to_s, out: File::NULL, err: File::NULL)
        waiter.join(STOP_SECONDS)
      end
    end
  end
end
