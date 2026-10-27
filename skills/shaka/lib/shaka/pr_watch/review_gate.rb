# frozen_string_literal: true

module Shaka
  class PrWatch
    # Applies the trusted none/one/all review wait to configured CI job runs.
    module ReviewGate
      private

      def review_jobs_terminal?(checks)
        return true if @ci_jobs.empty? || @ci_wait == 'none'

        results = @ci_jobs.map do |name|
          rows = checks.select { |row| row['name'] == name }
          !rows.empty? && terminal?(rows)
        end
        @ci_wait == 'all' ? results.all? : results.any?
      end

      def observe_checks
        snapshot = @status.call
        reason = snapshot_stop(snapshot)
        return reason if reason

        checks = @github.checks
        return 'head_moved' if @github.snapshot['headRefOid'] != @head

        settle_checks(snapshot['requiredChecks'], checks)
      end

      def snapshot_stop(snapshot)
        return 'head_moved' if snapshot['headRefOid'] != @head
        return 'closed' unless snapshot['state'] == 'OPEN'
        return unless snapshot['requiredChecksUnavailable']

        raise Error, snapshot['requiredChecksUnavailable']
      end

      def settle_checks(required, checks)
        terminal = terminal_checks?(required, checks)
        record_throughput(required, checks) if terminal
        update_pending(new_comments?, terminal)
        nil
      end

      def record_throughput(required, checks)
        return unless @throughput && gate_green?(required, checks)

        @throughput.call(required: required_names(required))
      # Throughput is a side record; no failure in it may stop the watch from waking.
      rescue StandardError
        nil
      end

      def required_names(required) = required.filter_map { |row| row['name'] if row.is_a?(Hash) }

      def gate_green?(required, checks)
        required.all? { |row| required_green?(row) } && review_green?(checks)
      end

      # Merge treats a skipped or neutral required check as satisfied. A review job does not.
      def required_green?(row) = row.is_a?(Hash) && (row['bucket'] == 'pass' || skipped_required?(row))
      def skipped_required?(row) = row['bucket'] == 'skipping' && %w[SKIPPED NEUTRAL].include?(row['state'])

      def review_green?(checks)
        return true if @ci_jobs.empty? || @ci_wait == 'none'

        passed = @ci_jobs.count { |name| job_passed?(checks, name) }
        @ci_wait == 'all' ? passed == @ci_jobs.size : passed.positive?
      end

      def job_passed?(checks, name)
        checks.any? { |row| row.is_a?(Hash) && row['name'] == name && row['bucket'] == 'pass' }
      end
    end
  end
end
