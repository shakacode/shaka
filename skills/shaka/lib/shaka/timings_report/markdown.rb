# frozen_string_literal: true

require_relative '../publication/run_summary'

module Shaka
  module TimingsReport
    # Renders the report for a retrospective: the ranked list first, then the weekly trend.
    module Markdown
      BUCKETS = ['| Where the time went | Total | PRs | Median per PR | p90 per PR |',
                 '| --- | ---: | ---: | ---: | ---: |'].freeze
      WEEKS = ['| Week of | PRs | Task to merge (median) | Validation | Local review | Agent working | ' \
               'Failed validations |', '| --- | ---: | ---: | ---: | ---: | ---: | ---: |'].freeze

      module_function

      def call(report)
        [heading(report), buckets(report['buckets']), weeks(report['weeks']), slowest(report['slowest'])]
          .compact.join("\n\n")
      end

      def heading(report)
        "## Timings for #{report['repository']}, #{report['since']} to #{report['until'] || 'now'}\n\n" \
          "#{report['with_timings']} of #{report['merged_pull_requests']} merged pull requests carried timings." \
          "#{truncated(report)}#{partial(report)} Ranked by total time. Rows overlap: validation phases and " \
          'machine sleep are part of the steps they name, and agent time includes the steps the agent waited on.'
      end

      def partial(report)
        count = report['partial'].to_i
        " #{count} kept only their latest steps, so their step totals are low." if count.positive?
      end

      def truncated(report)
        " The search stopped at the --limit of #{report['limit']}; raise it to include more." if report['truncated']
      end

      def buckets(buckets)
        return 'No merged pull request in this range carried timings.' if buckets.empty?

        rows = buckets.map do |bucket|
          cells = [bucket['name'], time(bucket['total_ms']), bucket['pull_requests'], time(bucket['median_ms']),
                   time(bucket['p90_ms'])]
          "| #{cells.join(' | ')} |"
        end
        [*BUCKETS, *rows].join("\n")
      end

      def weeks(weeks)
        return if weeks.empty?

        rows = weeks.map do |week|
          times = week.values_at('median_validation_ms', 'median_review_ms', 'median_agent_working_ms')
          cells = [week['week'], week['pull_requests'], elapsed(week['median_task_to_merge_ms']),
                   *times.map { |value| time(value) }, week['failed_validations']]
          "| #{cells.join(' | ')} |"
        end
        [*WEEKS, *rows].join("\n")
      end

      def slowest(rows)
        return if rows.empty?

        links = rows.map { |row| "[##{row['number']}](#{row['url']}) #{elapsed(row['task_to_merge_ms'])}" }
        "Slowest from task start to merge: #{links.join(' · ')}"
      end

      def time(milliseconds) = milliseconds ? RunSummary.duration(milliseconds) : '—'
      def elapsed(milliseconds) = milliseconds ? RunSummary.elapsed(milliseconds / 1000.0) : '—'
    end
  end
end
