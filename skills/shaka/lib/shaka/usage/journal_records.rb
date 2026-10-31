# frozen_string_literal: true

require_relative '../publication/usage_details'

module Shaka
  # The identity fields hold no whole-task flag, so a snapshot lists those responses beside its records.
  module UsageJournalWholeTask
    NAME = 'shaka:usage-journal-whole-task'
    LINE = /^<!-- #{NAME} (\[[^\n]*\]) -->$/

    module_function

    def line(records)
      responses = records.select { |record| record['covers_task'] == true }.flat_map { |record| record['responses'] }
      "<!-- #{NAME} #{JSON.generate(responses.uniq)} -->" unless responses.empty?
    end

    def responses(body)
      listed = body[LINE, 1]
      listed ? JSON.parse(listed) : []
    end

    def mark(record, covering)
      record['responses'].intersect?(covering) ? record.merge('covers_task' => true) : record
    end
  end

  # Reduces immutable response snapshots, preserving attribution without counting copies again.
  module UsageJournalRecords
    PRICED = %w[usd credits].freeze
    OBSERVED = %w[provider model routed effort input cached_input output reasoning_output cache_writes].freeze

    module_function

    def parse(body)
      blocks = UsageRecords.parsed_blocks(body)
      if blocks.empty? || UsageRecords.unterminated(body).positive?
        raise Error, 'Usage journal contains malformed records.'
      end

      parse_blocks(blocks, UsageJournalWholeTask.responses(body))
    rescue JSON::ParserError
      raise Error, 'Usage journal contains malformed columns.'
    end

    # A snapshot writes each shared note once, so later records need it put back.
    def parse_blocks(blocks, covering)
      texts = blocks.map(&:first)
      UsagePricing.inline(texts, texts).zip(blocks).map do |block, (_text, identity)|
        UsageJournalWholeTask.mark(parse_record(block, identity), covering)
      end
    end

    def parse_record(block, identity)
      raise Error, 'Usage journal contains an invalid record.' unless identity && UsageRecordShape.report_shape?(block)

      columns = JSON.parse(block[UsageDetails::HIDDEN, 1].to_s)
      identity.merge('columns' => columns, 'note' => UsagePricing.from_block(block))
    end

    def combine(records)
      raise Error, 'Usage journal records must be a list.' unless records.is_a?(Array)

      # Validate stored columns and notes before using any of them.
      records.each { |record| validate(record) }
      measured = records.select { |record| record['responses'].any? }
      remaining = records.reject { |record| placeholder_covered?(record, measured) }
      remaining.each_with_object([]) { |record, kept| fold(kept, record) }
    end

    def placeholder_covered?(old, measured)
      old['responses'].empty? && measured.any? do |fresh|
        old['host'] == fresh['host'] && (old['sources'].empty? || old['sources'].intersect?(fresh['sources'])) &&
          UsageRecords.same_attribution?(old, fresh)
      end
    end

    def validate(record)
      UsageDetails.new('note' => '', 'records' => [record]).detail
      return if record['responses'].size <= 1 && record['columns'].one?

      raise Error, 'Usage journal requires native response records, not aggregate reports.'
    end

    def fold(kept, record)
      old = kept.find { |entry| overlapping?(entry, record) }
      return kept << record.dup unless old

      kept[kept.index(old)] = merge_copy(old, record)
    end

    def overlapping?(old, record)
      return false unless old['host'] == record['host']
      return true if old['responses'].intersect?(record['responses'])
      return false unless old['responses'].empty? && record['responses'].empty?

      old.values_at('sources', 'contribution', 'commits') == record.values_at('sources', 'contribution', 'commits')
    end

    def merge_copy(old, record)
      merged = old.merge(attribution(old, record), intervals(old, record), merged_fields(old, record))
      record['covers_task'] == true ? merged.merge('covers_task' => true) : merged
    end

    def merged_fields(old, record)
      columns = merge_column(old, record)
      shared_label(columns, old, record)
      { 'columns' => [columns], 'commits' => (old['commits'] + record['commits']).uniq,
        'complete' => old['complete'] || record['complete'] }
    end

    def shared_label(columns, old, record)
      return if old['contribution'] == record['contribution']

      columns['label'] = columns['label'].sub(/#{Regexp.escape(old['contribution'])}\z/, 'shared-planning')
    end

    def intervals(old, record)
      %w[from to].to_h { |key| [key, old[key] == 'UNKNOWN' ? record[key] : old[key]] }
    end

    def attribution(old, record)
      categories = (categories(old) + categories(record)).uniq.sort
      note = pricing_note(old, record)
      return { 'note' => note, 'contribution' => old['contribution'] } if categories == categories(old).sort

      note = note.to_s.sub(/\n\nAttribution categories: [^\n]*\.\z/, '')
      { 'contribution' => 'shared-planning',
        'note' => "#{note}\n\nAttribution categories: #{categories.join(', ')}." }
    end

    # A price stays with the note explaining it: the first measured one, or the copy that first supplies it.
    def pricing_note(old, record)
      priced = PRICED.any? do |key|
        old['columns'].first[key] == 'UNKNOWN' && record['columns'].first[key] != 'UNKNOWN'
      end
      priced ? record['note'] : old['note']
    end

    def categories(record)
      prior = record['note'].to_s[/Attribution categories: ([^\n]*)\.\z/, 1]
      return [record['contribution']] unless record['contribution'] == 'shared-planning' && prior

      prior.split(', ').intersection(UsageRecordCarry::CONTRIBUTIONS)
    end

    def merge_column(old, record)
      fresh = record['columns'].first
      old['columns'].first.to_h do |key, value|
        incoming = fresh.fetch(key)
        if OBSERVED.include?(key) && ![value, incoming].include?('UNKNOWN') && value != incoming
          raise Error, "Usage journal has conflicting #{key} for response #{old['responses'].first}; " \
                       'inspect the PR comments holding that response.'
        end

        [key, value == 'UNKNOWN' ? incoming : value]
      end
    end
  end
end
