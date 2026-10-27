# frozen_string_literal: true

module Shaka
  # Counts CI rounds and finds the GitHub time the gate turned green.
  module ThroughputGate
    FAILURES = %w[FAILURE TIMED_OUT STARTUP_FAILURE ACTION_REQUIRED].freeze
    SUCCESS = %w[SUCCESS SKIPPED NEUTRAL].freeze

    def rounds(heads)
      count = 0
      previous_failed = false
      Array(heads).each { |head| count, previous_failed = next_round(count, previous_failed, head) }
      count.positive? ? count : nil
    end

    # [heads oldest first, true when no check-suite page was cut off]
    def ci_heads(commits, required:, review_jobs:)
      names = Array(required) + Array(review_jobs)
      seen = Array(commits).filter_map { |commit| one_head(commit, names) }
      [seen.filter_map { |row| row[:head] }, seen.none? { |row| row[:cut] }]
    end

    def first_push(heads)
      Array(heads).filter_map { |head| head['pushed_at'] if head.is_a?(Hash) && head['pushed_at'].is_a?(String) }.first
    end

    # A partial commit page must not replace an earlier push, and must not invent one.
    def bounded_first_push(heads, complete, carried)
      seen = first_push(heads)
      kept = carried['first_push']
      return earlier_push(seen, kept) if complete && seen
      return 'UNKNOWN' unless complete || kept_push?(kept)

      nil
    end

    # Time the gate turned green, :unknown when it is green without timestamps, or nil when it is not green.
    def ready_at(rows, required:, review_jobs:, wait:)
      selected = selected_rows(Array(rows).grep(Hash), required, review_jobs, wait)
      return if selected.nil? || selected.empty?

      times = selected.map { |row| parse_time(row['completedAt']) }
      times.any?(&:nil?) ? :unknown : times.max
    end

    private

    def kept_push?(value) = value.is_a?(String) && !value.empty? && value != 'UNKNOWN'
    def earlier_push(seen, kept) = kept_push?(kept) ? [seen, kept].min : seen

    def next_round(count, previous_failed, head)
      return [count, previous_failed] unless head.is_a?(Hash)

      [(count.zero? || previous_failed ? count + 1 : count), head['failed'] == true]
    end

    def one_head(commit, names)
      return unless commit.is_a?(Hash)

      runs, cut = runs_of(commit)
      sample = relevant(runs, names)
      { head: (head_row(commit, sample) unless sample.empty?), cut: cut } if !sample.empty? || cut
    end

    def head_row(commit, sample)
      { 'sha' => commit['oid'], 'pushed_at' => prompt_stamp(commit), 'failed' => failed?(sample) }
    end

    def selected_rows(rows, required, review_jobs, wait)
      needed = Array(required).map { |name| latest(rows, name) }
      return if needed.any?(&:nil?) || needed.any? { |row| !passed?(row) }

      extra = review_rows(rows, review_jobs, wait)
      extra && (needed + extra)
    end

    def review_rows(rows, jobs, wait)
      jobs = Array(jobs)
      return [] if jobs.empty? || wait.to_s == 'none'

      chosen = jobs.filter_map { |name| latest(rows, name) }.select { |row| passed?(row) }
      return unless review_met?(chosen, jobs, wait)

      wait.to_s == 'all' ? chosen : [earliest(chosen)]
    end

    def review_met?(chosen, jobs, wait) = wait.to_s == 'all' ? chosen.size == jobs.size : !chosen.empty?

    def earliest(chosen) = chosen.min_by { |row| row['completedAt'].to_s }
    def latest(rows, name) = rows.select { |row| row['name'] == name }.max_by { |row| row['completedAt'].to_s }

    def passed?(row)
      return row['bucket'] == 'pass' || skipped_bucket?(row) if row.key?('bucket')

      SUCCESS.include?(row['conclusion'])
    end

    def skipped_bucket?(row) = row['bucket'] == 'skipping' && %w[SKIPPED NEUTRAL].include?(row['state'])
    def relevant(runs, names) = names.empty? ? runs : runs.select { |run| names.include?(run['name']) }

    def runs_of(commit)
      runs, cut = suite_page(commit['checkSuites'])
      [runs + status_runs(commit['status']), cut]
    end

    def status_runs(status)
      return [] unless status.is_a?(Hash)

      Array(status['contexts']).grep(Hash).map { |row| status_run(row) }
    end

    def status_run(row)
      state = row['state']
      { 'name' => row['context'], 'status' => pending_status?(state) ? state : 'COMPLETED',
        'conclusion' => state == 'ERROR' ? 'FAILURE' : state, 'completedAt' => row['createdAt'] }
    end

    def pending_status?(state) = %w[PENDING EXPECTED].include?(state)

    def suite_page(suites)
      nodes = suites.is_a?(Hash) ? Array(suites['nodes']) : []
      parts = nodes.map { |suite| runs_in(suite) }
      cut = (suites.is_a?(Hash) && suites.dig('pageInfo', 'hasNextPage') == true) || parts.any?(&:last)
      [parts.flat_map(&:first), cut]
    end

    def runs_in(suite)
      return [[], false] unless suite.is_a?(Hash)

      page = suite['checkRuns']
      nodes = page.is_a?(Hash) ? Array(page['nodes']).grep(Hash) : []
      [nodes, page.is_a?(Hash) && page.dig('pageInfo', 'hasNextPage') == true]
    end

    def failed?(runs) = runs.any? { |run| run['status'] == 'COMPLETED' && FAILURES.include?(run['conclusion']) }
  end
end
