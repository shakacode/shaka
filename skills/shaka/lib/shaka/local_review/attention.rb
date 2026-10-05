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
                  'No open findings; closed and optional findings are in history.'
                else
                  "#{pending.size} #{pending.size == 1 ? 'finding needs' : 'findings need'} attention."
                end
      ["**Outcome:** #{outcome}", *finding_table(pending)]
    end

    def details
      ['### Finding details', *@findings.values.map { |copies| line(copies) }]
    end

    private

    def partition
      @findings.values.partition { |copies| LocalReviewFinding.pending?(copies) }
    end

    def finding_table(pending)
      return [] if pending.empty?

      rows = pending.map { |copies| finding_row(copies) }
      [(['| Finding | Status | Reported by |', '| --- | --- | --- |'] + rows).join("\n")]
    end

    def finding_row(copies)
      finding = copies.last
      text = "`#{finding.id}` · #{finding.summary}"
      text += ' · **returned after its fix**' if copies[0...-1].any?(&:fixed?)
      text += ' · **earlier defect/risk remains unassessed**' if reclassified?(copies)
      cells = [text, finding.status, reporters(finding.id).join(', ')].map { |cell| PublicationText.table_cell(cell) }
      "| #{cells.join(' | ')} |"
    end

    def reclassified?(copies)
      !copies.last.closed? && copies.last.kind == 'nit' && copies.any? { |item| item.kind != 'nit' }
    end

    def line(copies)
      finding = copies.last
      previous_fix = copies[0...-1].reverse.find(&:fixed?)
      fixed = previous_fix ? { finding.id => previous_fix.commit } : {}
      text = LocalReviewTriage.line(finding, @links, fixed)
      text += ' · **earlier defect/risk remains unassessed**' if reclassified?(copies)
      "#{text} · #{attribution(finding)}"
    end

    def attribution(finding)
      source = @rounds.reverse.find { |round| round.findings.include?(finding) }
      "Reported by: #{reporters(finding.id).join(', ')} · last recorded at #{@links.commit(source.head)}"
    end

    def reporters(id)
      @rounds.select { |round| round.findings.any? { |finding| finding.id == id } }.map(&:reviewer).uniq
    end
  end
end
