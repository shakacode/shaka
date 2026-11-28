# frozen_string_literal: true

require_relative 'text'

module Shaka
  # Records are supplied by the task owner; Ruby checks shape, not the evidence's truth.
  class SkillsUsed
    SUMMARY = 'Skills used'
    FIELDS = %w[name source revision phase contribution evidence corroboration].freeze
    # An upstream repository and optional path, such as cursor/plugins/pstack, so renamed ports count together.
    # A segment may start with a dot, as a hidden directory does, but may not be . or ..
    PACK_SEGMENT = %r{(?!\.\.?(?:/|\z))[\w.-]+}
    PACK = %r{\A#{PACK_SEGMENT}(?:/#{PACK_SEGMENT})+\z}
    LABELS = { 'agent-reported' => 'Agent-reported', 'corroborated' => 'Corroborated' }.freeze
    NOTE = 'Agent-reported use is the agent’s account. The agent selects Corroborated when a record confirms ' \
           'invocation or loading. Shaka does not check that record or instruction compliance. ' \
           'Completeness is not verified.'

    def self.refuse_free_form!(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(SUMMARY) }

      raise Error, 'Publication Skills used must be supplied as skills_used, not a details item.'
    end

    def initialize(records)
      @records = PublicationText.list(records, 'skills_used')
    end

    def detail
      rows = @records.map { |record| row(record) }
      # Every managed PR uses Shaka, and provenance already names the workflow version that ran.
      listed = rows.zip(@records).reject { |_, record| shaka?(record) }.map(&:first).uniq
      { 'summary' => SUMMARY, 'body' => "#{body(rows, listed)}\n\n#{NOTE}" }
    end

    private

    def shaka?(record)
      record['name'].casecmp?('shaka') && record['source'].casecmp?('ShakaCode/shaka')
    end

    def body(rows, listed)
      return table(listed) if listed.any?
      return 'No skills besides Shaka were reported.' if rows.any?

      'No skill use recorded; coverage is UNKNOWN.'
    end

    # The Pack column appears only when a record names one, so older reports render unchanged.
    def table(rows)
      header = %w[Skill Pack Source Revision Phase Contribution Evidence Corroboration]
      packed = rows.any? { |cells| cells[1] }
      header, *rows = [header, *rows].map { |cells| packed ? cells.map { it || '—' } : cells.values_at(0, 2..) }
      [header, ['---'] * header.size, *rows].map { |cells| "| #{cells.join(' | ')} |" }.join("\n")
    end

    def row(record)
      check_fields!(record)
      evidence = LABELS.fetch(record['evidence']) { raise Error, 'Publication skills_used evidence is invalid.' }
      name, *cells = %w[name source revision phase contribution].map { |field| cell(record[field], field) }
      [name, pack(record), *cells, evidence, corroboration(record)]
    end

    def check_fields!(record)
      return if record.is_a?(Hash) && record.keys.all?(String) && (record.keys - ['pack']).sort == FIELDS.sort

      raise Error, 'Publication skills_used record fields do not match the metadata allowlist.'
    end

    def pack(record)
      return unless record.key?('pack')
      # A code span keeps Markdown such as _core_ literal, so the rendered key matches the recorded one.
      return "`#{record['pack']}`" if record['pack'].is_a?(String) && record['pack'].match?(PACK)

      raise Error, 'Publication skills_used pack must be OWNER/REPO or OWNER/REPO/PATH, such as ' \
                   'cursor/plugins/pstack, using ASCII letters, digits, ., _, and -, with no . or .. part.'
    end

    def corroboration(record)
      return cell(record['corroboration'], 'corroboration') if record['evidence'] == 'corroborated'
      return '—' if record['corroboration'].nil?

      raise Error, 'Publication agent-reported skill use requires null corroboration.'
    end

    def cell(value, field)
      PublicationText.table_cell(PublicationText.summary_text(value, "skills_used #{field}"))
    end
  end
end
