# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Renders how the reviews of one commit were collated: which of each reviewer's own findings
  # became which finding, then what became of each finding, once.
  class LocalReviewTriage
    def self.line(finding, links, fixed_before)
      result = finding.fixed? ? "fixed in #{links.commit(finding.commit)}" : finding.label
      line = "- `#{finding.id}` #{finding.kind}: #{finding.summary} — #{result}"
      line += " — #{finding.note}" if finding.note
      returned = fixed_before[finding.id]
      returned ? "#{line} · **returned after its fix in #{links.commit(returned)}**" : line
    end

    # The rounds of one commit share one triage, so a finding they share has one outcome. A ledger
    # always records it that way; a hand-written content file might not.
    def self.check!(rounds)
      rounds.chunk(&:head).each do |head, batch|
        split = batch.flat_map(&:findings).group_by(&:id).find { |_, copies| outcomes(copies) > 1 }
        raise Error, "Finding #{split.first} has two outcomes in the reviews of #{head[0, 7]}." if split
      end
    end

    def self.outcomes(copies) = copies.map { |item| [item.kind, item.disposition, item.commit] }.uniq.size

    # The rounds of one commit. With several reviewers: each report with how its findings were
    # collated, then the commit's triage.
    def self.details(head, batch, links, fixed)
      return [batch.first.details(links, fixed)] if batch.one?

      batch.map { |round| round.details(links, fixed, collated: true) } + [new(head, batch, links).render(fixed)]
    end

    # Under one reviewer's collapsed report: its own findings and the finding each became.
    def self.collated_as(round)
      return '' if round.findings.empty?

      pairs = round.findings.map { |finding| "`##{finding.reported_as || '?'}` → `#{finding.id}`" }
      "**Collated as:** #{pairs.join(', ')}\n\n"
    end

    def initialize(head, batch, links)
      @head = head
      @batch = batch
      @links = links
    end

    def render(fixed_before)
      findings = @batch.flat_map(&:findings).uniq(&:id)
      title = "**Triage of #{@links.commit(@head)}**"
      return "#{title}: no findings." if findings.empty?

      lines = findings.map do |finding|
        "#{self.class.line(finding, @links, fixed_before)} — reported by #{reporters(finding.id)}"
      end
      "#{title}\n\n#{lines.join("\n")}"
    end

    private

    def reporters(id)
      @batch.filter_map do |round|
        finding = round.findings.find { |item| item.id == id }
        next unless finding

        finding.reported_as ? "#{round.reviewer} ##{finding.reported_as}" : round.reviewer
      end.join(', ')
    end
  end
end
