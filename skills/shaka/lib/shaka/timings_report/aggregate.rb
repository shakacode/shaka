# frozen_string_literal: true

require 'date'

module Shaka
  module TimingsReport
    # Ranks where the time went across pull requests and groups the trend by the week each merged.
    module Aggregate
      module_function

      def call(rows, considered, options)
        { 'repository' => options[:repository], 'since' => options[:since].iso8601,
          'until' => options[:until]&.iso8601, 'merged_pull_requests' => considered, 'with_timings' => rows.size,
          'limit' => options[:limit], 'truncated' => considered >= options[:limit].to_i,
          'partial' => rows.count { |row| row['dropped_steps'].positive? },
          'buckets' => ranked(rows), 'weeks' => weeks(rows), 'slowest' => slowest(rows) }
      end

      # Buckets ranked by their total across all pull requests: the order to look for savings in.
      # Agent working is the sum of the agent rows, so it would always rank first; it stays in the weeks.
      TOTALS_ONLY = ['Agent working'].freeze

      def ranked(rows)
        names = rows.flat_map { |row| row['buckets'].keys }.uniq - TOTALS_ONLY
        names.map { |name| bucket(name, rows.filter_map { |row| row['buckets'][name] }) }
             .sort_by { |bucket| -bucket['total_ms'] }
      end

      def bucket(name, values)
        { 'name' => name, 'total_ms' => values.sum, 'pull_requests' => values.size,
          'median_ms' => percentile(values, 0.5), 'p90_ms' => percentile(values, 0.9) }
      end

      def weeks(rows)
        grouped = rows.group_by { |row| monday(row['merged_at']) }
        grouped.sort.map { |week, group| week(week, group) }
      end

      def week(week, group)
        # Like the ranked list, a bucket's median covers only the pull requests that carry it.
        median = ->(name) { percentile(group.filter_map { |row| row['buckets'][name] }, 0.5) }
        { 'week' => week.iso8601, 'pull_requests' => group.size,
          'median_task_to_merge_ms' => percentile(group.map { |row| row['task_to_merge_ms'] }, 0.5),
          'median_validation_ms' => median.call('Validation'), 'median_review_ms' => median.call('Local review'),
          'median_agent_working_ms' => median.call('Agent working'),
          'failed_validations' => group.sum { |row| row['failed_validations'] } }
      end

      def monday(time)
        day = Date.iso8601(time[0, 10])
        day - (day.cwday - 1)
      end

      def slowest(rows)
        rows.max_by(5) { |row| row['task_to_merge_ms'] }.map { |row| row.slice('number', 'url', 'task_to_merge_ms') }
      end

      # Nil when no pull request carried the bucket, so the report shows no data rather than zero.
      def percentile(values, fraction)
        sorted = values.sort
        sorted[((sorted.size - 1) * fraction).round] unless sorted.empty?
      end
    end
  end
end
