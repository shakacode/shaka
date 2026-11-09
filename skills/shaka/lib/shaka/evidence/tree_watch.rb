# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative 'candidate_tree'

module Shaka
  module Evidence
    # Runs a check in its own process group and recaptures the candidate tree while it runs.
    # An edit to the checkout voids the result anyway, so the check stops within one interval
    # plus a capture instead of finishing first. Only the check's own group is signaled.
    class TreeWatch
      MESSAGE = 'worktree changed mid-run'
      # Seconds between captures. One capture took about 2 seconds on this repository under heavy
      # load, so an edit stops the check well within a minute.
      DEFAULT_INTERVAL = 15
      # Seconds the check gets to exit after TERM before its group is killed.
      GRACE = 5
      Outcome = Data.define(:status, :changed_tree) do
        def stopped? = !changed_tree.nil?

        # Result fields that say why the check did not finish.
        def stop_fields = stopped? ? { 'stop_reason' => MESSAGE } : {}
      end

      class << self
        attr_accessor :interval
      end
      self.interval = DEFAULT_INTERVAL

      def initialize(command, root:, tree:, interval: self.class.interval)
        @command = command
        @root = root
        @tree = tree
        @interval = interval
      end

      # Writes the check's output and then its errors to standard error once it ends.
      def run
        Open3.popen3(*@command, chdir: @root, pgroup: true) do |input, output, error, waiter|
          input.close
          readers = [output, error].map { |stream| Thread.new { stream.read } }
          changed = watch(waiter)
          $stderr.write(*readers.map(&:value))
          Outcome.new(status: waiter.value, changed_tree: changed)
        ensure
          # An interrupted helper would otherwise leave the check running in its separate group.
          stop(waiter) if waiter&.alive?
        end
      end

      private

      def watch(waiter)
        until waiter.join(@interval)
          current = capture
          return stop(waiter, current) if current && current != @tree
        end
        nil
      end

      # A file can vanish while Git stages it. The next capture, or the comparison after the
      # check, decides instead.
      def capture
        CandidateTree.capture(root: @root)
      rescue Error
        nil
      end

      # The group outlives its leader when a child ignores TERM, so KILL follows either way.
      def stop(waiter, tree = nil)
        warn "shaka: #{MESSAGE}; stopping the check" if tree
        signal('TERM', waiter.pid)
        waiter.join(GRACE)
        signal('KILL', waiter.pid)
        tree
      end

      def signal(name, pid)
        Process.kill(name, -pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
