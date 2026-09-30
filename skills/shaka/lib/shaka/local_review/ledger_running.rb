# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Marks the reviews still running on a commit, so its findings are recorded only after every
  # reviewer finishes and one triage sees all of them.
  module LocalReviewLedgerRunning
    # Checks a round may start and marks its reviewer running, owned by this process.
    def start!(base:, head:, reviewer:)
      locked do
        check_next!(base:, head:, reviewer:)
        raise Error, "#{reviewer} is already reviewing #{head}; wait for that review." if
          live(head).any? { |entry| entry['reviewer'].to_s.casecmp?(reviewer.to_s) }

        write_running(running + [{ 'head' => head, 'reviewer' => reviewer, 'pid' => Process.pid }])
      end
    end

    # Clears this process's mark after a run that ended without a round, such as a failed reviewer.
    def finish! = locked { clear_running }

    private

    def running = data.fetch('running', [])

    def live(head) = running.select { |entry| entry['head'] == head && alive?(entry['pid']) }

    # Only the process that set a mark clears it, so a refused or duplicate run leaves others alone.
    def clear_running = write_running(running.reject { |entry| entry['pid'] == Process.pid })

    def write_running(entries)
      write(entries.empty? ? data.except('running') : data.merge('running' => entries))
    end

    # A review whose process exited without clearing its mark, such as one killed, no longer blocks.
    def check_nothing_running!
      waiting = live(last_head)
      return if waiting.empty?

      raise Error, "Wait for #{waiting.map { |entry| entry['reviewer'] }.join(' and ')} to finish reviewing " \
                   "#{last_head} before recording."
    end

    def alive?(pid)
      Process.kill(0, Integer(pid))
      true
    rescue Errno::ESRCH, ArgumentError, TypeError
      false
    rescue Errno::EPERM
      true
    end
  end
end
