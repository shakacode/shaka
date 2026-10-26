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

        ['Shaka commits this run covers:', *list.map { |line| "- #{line}" }].join("\n")
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
      TASK = 'Add a farewell function beside the existing greeting. It returns the string goodbye. ' \
             'Add a test that asserts that return value, and add one line to docs/notes.md that names farewell. ' \
             'Do not change unrelated files.'

      module_function

      def render(sha:, repo:)
        <<~TEXT
          You are running Shaka's canary. Use the installed Shaka skill and follow its workflow. Do not merge or approve.

          Repository: #{repo}. This checkout is that repository.
          Shaka revision under test: #{sha}
          https://github.com/shakacode/shaka/commit/#{sha}

          The trusted Shaka skill is already installed for Cursor. Use that skill. Do not copy the skill into this repository.

          Task: #{TASK}

          Open one pull request for that task. Stop when the pull request is open. Do not merge it.
        TEXT
      end
    end
  end
end
