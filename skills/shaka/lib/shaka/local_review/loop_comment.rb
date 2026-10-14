# frozen_string_literal: true

require_relative 'comment'
require_relative 'attention'

module Shaka
  # The whole review loop in one comment: the current outcome once, a row per reviewed commit, one
  # disclosure for findings and execution metadata, and each commit's reports collapsed beneath it.
  # When GitHub's size limit cannot hold every report, the oldest commits' reports move into
  # continuation comments; each comment closes with its newest round's attestation, where `merge` reads it.
  class LocalReviewLoopComment < LocalReviewComment
    LIMIT = 65_536
    # Keyed by the ledger's first reviewed commit and its identity, so the same loop republishes in
    # place while a fresh ledger gets its own comment, even from the same commit. A ledger written
    # before identities existed, or a host review's content file, falls back to its first report.
    LOOP_KEY = 'local-review-loop'
    LEDGER_ID = /\A\h{12}\z/
    FINDINGS = 'Findings, assessments, and execution metadata'

    # One comment to publish. `summaries` lists every disclosure summary in the order GitHub must show them.
    Part = Struct.new(:key, :body, :attestation, :summaries) do
      def size = "<!-- shaka:reply:#{key} -->\n#{body}".length

      # Reports are published verbatim, so a stray fence or disclosure tag in one can swallow the rest
      # of the comment. GitHub's own rendering decides that; a regex over Markdown cannot.
      def check_rendering!(html)
        closing = %r{<p\b[^>]*>#{Regexp.escape(CGI.escapeHTML(attestation))}</p>\s*\z}
        disclosures = [html.scan(/<details\b/).size, html.scan('</details>').size]
        return if html.match?(closing) && disclosures == [summaries.size] * 2 && in_order?(html)

        raise Error, 'A review report leaves its markup open or adds disclosure tags, so GitHub would not show ' \
                     'each round collapsed with the attestation last. Fix the report and publish again.'
      end

      private

      def in_order?(html)
        offset = 0
        summaries.all? do |summary|
          found = html.index("<summary>#{summary}</summary>", offset)
          offset = found + 1 if found
        end
      end
    end

    def initialize(content, subject: ->(_) { 'Commit subject unavailable.' }, usage_url: nil, **)
      super(content, **)
      @subject = subject
      @ledger_id = content['id']
      raise Error, 'Local review ledger id must be 12 hexadecimal characters.' unless
        @ledger_id.nil? || @ledger_id.to_s.match?(LEDGER_ID)
      @usage_url = usage_url
      @commits = @rounds.chunk(&:head).map(&:last)
      @attention = LocalReviewAttention.new(@rounds, @links, assessments: @assessment_view)
    end

    def render = parts.first.body

    def key = "#{LOOP_KEY}-#{@rounds.first.head[0, 12]}-#{@ledger_id || @rounds.first.report_digest[0, 12]}"

    # The main comment first, keeping the newest commits' reports that fit; the rest follow, oldest first.
    def parts
      (0...@commits.size).each do |moved|
        main = main_part(moved)
        next if main.size > LIMIT && moved < @commits.size - 1

        return [main, *earlier_parts(@commits.take(moved))].each { |part| check_size!(part) }
      end
    end

    private

    def main_part(moved)
      shown = @commits.drop(moved)
      notes = {}
      earlier_groups(@commits.take(moved)).each_with_index do |group, index|
        group.each { |rounds| notes[rounds.first.head] = "reports in earlier comment #{index + 1}" }
      end
      blocks = [TITLE, "**Reviewed revision:** #{@links.commit(@rounds.last.head)}", *@attention.visible,
                *@assessment_view.unavailable, coverage(@commits.last), usage_link, *fallback_notice,
                *settings_notice, *bound, *budget_notice, commit_table(notes), findings,
                *shown.map { |rounds| section(rounds) }, @rounds.last.attestation]
      Part.new(key, "#{blocks.join("\n\n")}\n", @rounds.last.attestation, [FINDINGS, *summaries(shown)])
    end

    def earlier_parts(moved)
      earlier_groups(moved).each_with_index.map { |group, index| earlier_part(group, index + 1) }
    end

    # Packs the oldest commits into as few continuation comments as the limit allows, in ledger order.
    def earlier_groups(moved)
      moved.each_with_object([]) do |rounds, groups|
        if groups.empty? || earlier_part(groups.last + [rounds], groups.size).size > LIMIT
          groups << [rounds]
        else
          groups.last << rounds
        end
      end
    end

    def earlier_part(group, number)
      attestation = group.last.last.attestation
      blocks = ["#{TITLE} · earlier commits (#{number})",
                'Reports for earlier reviewed commits. The current outcome and findings are in the main ' \
                'Local Adversarial Review comment.',
                *group.map { |rounds| section(rounds) }, attestation]
      Part.new("#{key}-#{number}", "#{blocks.join("\n\n")}\n", attestation, summaries(group))
    end

    def check_size!(part)
      return if part.size <= LIMIT

      raise Error, "Review comment #{part.key} exceeds GitHub’s 65536-character limit even with one commit's " \
                   'reports; shorten its reports.'
    end

    def summaries(commits) = commits.flat_map { |rounds| [commit_summary(rounds), *rounds.map(&:summary)] }

    def commit_table(notes)
      rows = @commits.map do |rounds|
        head = rounds.first.head
        findings = rounds.map { |round| "#{round.reviewer}: #{round.finding_count}" }.join(' · ')
        findings += " · #{notes[head]}" if notes[head]
        line([@links.commit(head), findings])
      end
      ['**Reviewed commits:**', [line(%w[Commit Findings]), line(%w[--- ---]), *rows].join("\n")].join("\n\n")
    end

    def findings
      blocks = ["<details>\n<summary>#{FINDINGS}</summary>", *@attention.details, *@assessment_view.details,
                *@assessment_view.triage_history, *@assessment_view.triage_attribution,
                '### Execution metadata', table, '</details>']
      blocks.join("\n\n")
    end

    def section(rounds)
      blocks = ["<details>\n<summary>#{commit_summary(rounds)}</summary>",
                "**Commit:** #{@subject.call(rounds.first.head)}", coverage_reports(rounds),
                *LocalReviewTriage.details(rounds), '</details>']
      blocks.join("\n\n")
    end

    def commit_summary(rounds)
      count = rounds.sum { |round| round.findings.size }
      PublicationText.summary_text("Commit #{rounds.first.head[0, 7]} · #{rounds.map(&:reviewer).join(', ')} · " \
                                   "#{count} #{count == 1 ? 'finding' : 'findings'}", 'commit summary')
    end

    def coverage(rounds)
      groups = rounds.group_by { |round| round.value('coverage') || 'UNKNOWN; see evidence.' }
      values = groups.map { |text, grouped| "#{grouped.map(&:reviewer).join(', ')}: #{text}" }
      "**Coverage:** #{values.join(' · ')}"
    end

    def coverage_reports(rounds)
      lines = rounds.map do |round|
        value = round.value('coverage') || 'UNKNOWN; inspect the original report for limitations.'
        reported = round.reported_coverage || 'UNKNOWN; inspect the original report for complete coverage limits.'
        "- #{round.reviewer}: #{value}\n\n**Unverified report excerpt · #{round.reviewer}:**\n\n" \
          "<pre>#{literal(reported)}</pre>"
      end
      "**Review coverage:**\n\n" \
        "Coverage excerpts may be incomplete or misidentified; inspect the original reports.\n\n#{lines.join("\n")}"
    end

    # A pipe written as an entity displays the same, and keeps a table in the excerpt from
    # reaching the rendering check as one GitHub failed to render.
    def literal(text) = CGI.escapeHTML(text).gsub('|', '&#124;')

    def usage_link
      return 'Usage and attribution: see the PR description.' unless @usage_url

      "[Usage and attribution](#{@usage_url}) in the PR description."
    end

    def bound = LocalReviewBound.new(@rounds, @max_rounds, budget: @task_budget).lines

    def budget_notice = LocalReviewBudget.notice(@task_budget, completed: @rounds.size)
  end
end
