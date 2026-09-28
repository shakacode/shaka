# frozen_string_literal: true

require_relative 'error'
require_relative 'usage/usage_records'

module Shaka
  # Row order and label suffixes for the published usage table.
  module UsageTableText
    def disambiguate(built)
      seen = Hash.new(0)
      built.map do |column|
        seen[column['label']] += 1
        next column if seen[column['label']] == 1

        column.merge('label' => "#{column['label']}-#{seen[column['label']]}")
      end
    end

    def table_for(columns)
      labels = columns.map { |column| column['label'] }
      separator = ['---', *(['---:'] * labels.size)]
      rows = UsageDetails::METRICS.map { |key, label| [label, *columns.map { |column| column[key] }] }
      [['Metric', *labels], separator, *rows].map { |row| "| #{row.join(' | ')} |" }.join("\n")
    end

    # The current report's table is already visible. Its copy stays in comments so the
    # summary does not list the same amount twice, and a later publish can show it if carried.
    def record_blocks
      @records.map do |entry|
        body = entry['columns'] ? commented_table(table_for(entry['columns'])) : '<!-- retained usage record -->'
        "#{UsageRecords.begin_mark(entry['identity'])}\n#{body}\n#{UsageRecords::END_MARK}"
      end
    end

    def commented_table(table)
      table.lines.map { |line| "<!-- #{line.rstrip} -->" }.join("\n")
    end

    def visible_carried(text)
      text.gsub(/^<!-- (\|.*) -->$/, '\1')
    end
  end

  # Renders the PR usage table so every host publishes the same rows and alignment.
  class UsageDetails
    include UsageTableText

    SUMMARY = 'Usage and cost'
    METRICS = [
      ['credits', 'Credits estimate'],
      ['usd', 'USD estimate'],
      ['input', 'Input'],
      ['cached_input', 'Cached input'],
      ['output', 'Output'],
      ['reasoning_output', 'Reasoning output'],
      ['cache_writes', 'Cache writes']
    ].freeze
    COLUMN_KEYS = (%w[label provider model routed effort] + METRICS.map(&:first)).freeze
    REQUIRED = %w[note columns].freeze
    OPTIONAL = %w[records carried].freeze

    def self.usage_summary?(summary) = summary.to_s.match?(/usage/i)

    def initialize(spec)
      @spec = spec
    end

    def detail
      { 'summary' => SUMMARY, 'body' => body }
    end

    private

    def body
      checked
      parts = []
      parts << @note unless @note.empty?
      parts << table
      parts << visible_carried(@carried) unless @carried.empty?
      parts.concat(record_blocks)
      parts.join("\n\n")
    end

    def checked
      raise Error, 'Publication usage must be an object.' unless @spec.is_a?(Hash)

      refuse_keys(@spec.keys - (REQUIRED + OPTIONAL), 'has unknown fields')
      refuse_keys(REQUIRED - @spec.keys, 'is missing fields')
      @note = note(@spec['note'])
      @columns = columns(@spec['columns'])
      @carried = carried_text
      @records = records
    end

    def refuse_keys(keys, problem)
      raise Error, "Publication usage #{problem}: #{keys.join(', ')}." unless keys.empty?
    end

    def note(value)
      raise Error, 'Publication usage note must be text.' unless value.is_a?(String)

      PublicationText.checked(value.strip, 'usage note')
    end

    def columns(value)
      raise Error, 'Publication usage columns must be a list.' unless value.is_a?(Array)
      raise Error, 'Publication usage columns must include at least one column.' if value.empty?

      disambiguate(value.map.with_index { |column, index| column_cells(column, index) })
    end

    def column_cells(column, index)
      raise Error, "Publication usage column #{index + 1} must be an object." unless column.is_a?(Hash)

      column_keys(column, index)
      COLUMN_KEYS.to_h { |key| [key, cell(column, key, index)] }
    end

    def column_keys(column, index)
      missing = COLUMN_KEYS - column.keys
      extra = column.keys - COLUMN_KEYS
      return if missing.empty? && extra.empty?

      problem = missing.empty? ? "unknown fields: #{extra.join(', ')}" : "missing fields: #{missing.join(', ')}"
      raise Error, "Publication usage column #{index + 1} has #{problem}."
    end

    def cell(column, key, index)
      value = column[key]
      unless value.is_a?(String) && !value.strip.empty? && !value.match?(/[\r\n]/)
        raise Error, "Publication usage column #{index + 1} #{key} must be single-line nonempty text."
      end

      value.strip.gsub(/[\\|]/) { |character| "\\#{character}" }
    end

    def table = table_for(@columns)

    def carried_text
      return '' unless @spec.key?('carried')

      value = @spec['carried']
      raise Error, 'Publication usage carried must be text.' unless value.is_a?(String)

      PublicationText.checked(value.strip, 'usage carried')
    end

    def records
      return [] unless @spec.key?('records')

      value = @spec['records']
      raise Error, 'Publication usage records must be a list.' unless value.is_a?(Array)

      value.map { |fields| record_entry(fields) }
    end

    def record_entry(fields)
      raise Error, 'Publication usage record must be an object.' unless fields.is_a?(Hash)

      copied = fields.dup
      nested = copied.delete('columns')
      { 'identity' => UsageRecordCarry.identity!(copied), 'columns' => nested.nil? ? nil : columns(nested) }
    end
  end
end
