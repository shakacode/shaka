# frozen_string_literal: true

module Shaka
  module Canary
    # Renders the run summary posted to the workflow and the canary pull request.
    module Summary
      IDENTITY = '🤖 AGENT · github-actions · canary · UNKNOWN'
      MARKER = /<!-- shaka-canary elapsed_seconds=(\d+|UNKNOWN) spend=(\S+) -->/
      DIFF_LINES = 80

      module_function

      def render(report)
        [IDENTITY, headline(report), checks(report), timing(report), spend_line(report), commits(report),
         diff(report), marker(report), run_link(report)].join("\n\n")
      end

      def elapsed_marker(comments)
        Array(comments).each do |text|
          match = text.to_s.match(MARKER)
          return match[1] if match
        end
        'UNKNOWN'
      end

      def headline(report)
        state = report['ok'] ? 'passed' : 'failed'
        sha = report.fetch('shaka_sha')
        repo = report.fetch('shaka_repo')
        pr = report['canary_pr_url'] || 'no canary pull request opened'
        "Canary #{state} for [#{sha}](https://github.com/#{repo}/commit/#{sha}). Pull request: #{pr}."
      end

      def checks(report)
        rows = Array(report['checks'])
        return 'No automatic checks ran.' if rows.empty?

        lines = rows.map { |row| "- #{row['ok'] ? 'pass' : 'fail'} #{row['name']}: #{row['detail']}" }
        ['Automatic checks:', *lines].join("\n")
      end

      def timing(report)
        "Elapsed #{clock(report['elapsed_seconds'])}. Previous run #{clock(report['previous_elapsed_seconds'])}."
      end

      def spend_line(report)
        "Spend #{report.fetch('spend')}. Previous run #{report.fetch('previous_spend')}."
      end

      def commits(report)
        list = Array(report['commits'])
        return 'No Shaka commits were named for this run.' if list.empty?

        repo = report.fetch('shaka_repo')
        links = list.map { |line| "- [#{line}](https://github.com/#{repo}/commit/#{line.split.first})" }
        ['Shaka commits this run covers:', *links].join("\n")
      end

      def diff(report)
        text = report['diff'].to_s
        return text unless text.start_with?('--- previous')

        rows = text.lines
        shown = rows.size <= DIFF_LINES ? text : "#{rows.first(DIFF_LINES).join}… diff truncated\n"
        fence = '`' * [4, text.scan(/`+/).map(&:length).max.to_i + 1].max
        "#{fence}diff\n#{shown.chomp}\n#{fence}"
      end

      def marker(report)
        elapsed = report['elapsed_seconds'].is_a?(Integer) ? report['elapsed_seconds'] : 'UNKNOWN'
        "<!-- shaka-canary elapsed_seconds=#{elapsed} spend=#{report.fetch('spend')} -->"
      end

      def run_link(report)
        "Workflow run: #{report['run_url']}" if report['run_url']
      end

      def clock(seconds)
        return 'UNKNOWN' unless seconds.is_a?(Integer) && seconds >= 0
        return "#{seconds}s" if seconds < 60

        "#{seconds / 60}m #{seconds % 60}s"
      end
    end

    # The fixed task every canary run gives the headless agent.
    module Prompt
      module_function

      def render(sha:, repo:, branch:)
        File.read(File.expand_path('../../../config/canary-prompt.md', __dir__))
            .gsub('{{sha}}', sha).gsub('{{repo}}', repo).gsub('{{branch}}', branch)
      end
    end
  end
end
