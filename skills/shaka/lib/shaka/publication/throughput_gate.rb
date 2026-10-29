# frozen_string_literal: true

module Shaka
  # Finds the GitHub time the current head's gate turned green.
  module ThroughputGate
    # Time the gate turned green, :unknown when it is green without timestamps, or nil when it is not green.
    def ready_at(rows, required:, review_jobs:, wait:)
      selected = selected_rows(Array(rows).grep(Hash), required, review_jobs, wait)
      return if selected.nil? || selected.empty?

      times = selected.map { |row| plausible_time(row['completedAt']) }
      times.any?(&:nil?) ? :unknown : times.max
    end

    private

    def selected_rows(rows, required, review_jobs, wait)
      needed = Array(required).map { |name| latest(rows, name) }
      return if needed.any?(&:nil?) || needed.any? { |row| !passed?(row) }

      extra = review_rows(rows, review_jobs, wait)
      extra && (needed + extra)
    end

    def review_rows(rows, jobs, wait)
      jobs = Array(jobs)
      return [] if jobs.empty? || wait.to_s == 'none'

      chosen = jobs.filter_map { |name| latest(rows, name) }.select { |row| review_passed?(row) }
      return unless review_met?(chosen, jobs, wait)

      wait.to_s == 'all' ? chosen : [earliest(chosen)]
    end

    def review_met?(chosen, jobs, wait) = wait.to_s == 'all' ? chosen.size == jobs.size : !chosen.empty?

    def earliest(chosen) = chosen.min_by { |row| row['completedAt'].to_s }
    def latest(rows, name) = rows.select { |row| row['name'] == name }.max_by { |row| row['completedAt'].to_s }

    def passed?(row) = row['bucket'] == 'pass' || skipped_bucket?(row)

    # A skipped review does not satisfy the review gate, so it cannot mark the ready time.
    def review_passed?(row) = row['bucket'] == 'pass'

    def skipped_bucket?(row) = row['bucket'] == 'skipping' && %w[SKIPPED NEUTRAL].include?(row['state'])
  end
end
