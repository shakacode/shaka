# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Marks the reviews still running on a commit, so its findings are recorded only after every
  # reviewer finishes and one triage sees all of them.
  module LocalReviewLedgerRunning
    # Checks a round may start and marks its reviewer running.
    def start!(base:, head:, reviewer:)
      locked do
        check_next!(base:, head:, reviewer:)
        write_running(running + [{ 'head' => head, 'reviewer' => reviewer, 'pid' => Process.pid }])
      end
    end

    # Clears a run that ended without a round, such as a reviewer that failed.
    def finish!(head:, reviewer:) = locked { clear_running(head, reviewer) }

    private

    def running = data.fetch('running', [])

    def clear_running(head, reviewer)
      write_running(running.reject { |entry| entry['head'] == head && entry['reviewer'].to_s.casecmp?(reviewer.to_s) })
    end

    def write_running(entries)
      write(entries.empty? ? data.except('running') : data.merge('running' => entries))
    end

    # A review whose process exited without clearing its mark, such as one killed, no longer blocks.
    def check_nothing_running!
      waiting = running.select { |entry| entry['head'] == last_head && alive?(entry['pid']) }
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
