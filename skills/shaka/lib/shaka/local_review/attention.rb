# frozen_string_literal: true

module Shaka
  # A presentation of retained findings, not a new decision or a recommendation-quality judgment.
  # Legacy documented defects and risks remain visible even after a clean round or reclassification.
  class LocalReviewAttention
    def initialize(rounds, links)
      @rounds = rounds
      @links = links
      @findings = rounds.chunk(&:head).flat_map { |_, batch| batch.flat_map(&:findings).uniq(&:id) }.group_by(&:id)
    end

    def visible
      pending, = partition
      outcome = if pending.empty?
                  'No unresolved defects or risks recorded; optional findings are in history.'
                else
                  "#{pending.size} unresolved or unassessed #{pending.size == 1 ? 'finding' : 'findings'}."
                end
      ["**Outcome:** #{outcome}", *pending.map { |copies| line(copies) }]
    end

    def settled
      _, closed = partition
      return [] if closed.empty?

      ['### Settled and optional findings', *closed.map { |copies| line(copies) }]
    end

    private

    def partition
      @findings.values.partition do |copies|
        !copies.last.fixed? && copies.any? { |finding| finding.kind != 'nit' }
      end
    end

    def reclassified?(copies) = copies.last.kind == 'nit' && copies.any? { |item| item.kind != 'nit' }

    def line(copies)
      finding = copies.last
      previous_fix = copies[0...-1].reverse.find(&:fixed?)
      fixed = previous_fix ? { finding.id => previous_fix.commit } : {}
      source = @rounds.reverse.find { |round| round.findings.include?(finding) }
      text = LocalReviewTriage.line(finding, @links, fixed)
      text += ' · **earlier defect/risk remains unassessed**' if reclassified?(copies)
      "#{text} · last recorded at #{@links.commit(source.head)}"
    end
  end
end
