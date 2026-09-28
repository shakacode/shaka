# frozen_string_literal: true

require_relative 'error'
require_relative 'usage/usage_records'

module Shaka
  # Renders the PR usage table so every host publishes the same rows and alignment.
  class UsageDetails
    SUMMARY = 'Usage and cost'
    METRICS = [
      ['usd', 'USD estimate'],
      ['input', 'Input'],
      ['cached_input', 'Cached input'],
      ['output', 'Output'],
      ['reasoning_output', 'Reasoning output'],
      ['cache_writes', 'Cache writes']
    ].freeze
    COLUMN_KEYS = (%w[label provider model routed effort credits] + METRICS.map(&:first)).freeze
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
      parts << @carried unless @carried.empty?
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

      built = value.map.with_index { |column, index| column_cells(column, index) }
      labels = built.map { |column| column['label'] }
      raise Error, 'Publication usage columns repeat a label.' if labels.uniq.size != labels.size

      built
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

    def table
      labels = @columns.map { |column| column['label'] }
      separator = ['---', *(['---:'] * labels.size)]
      rows = METRICS.map { |key, label| [label, *@columns.map { |column| column[key] }] }
      [['Metric', *labels], separator, *rows].map { |row| "| #{row.join(' | ')} |" }.join("\n")
    end

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

      value.map { |fields| UsageRecordCarry.identity!(fields) }
    end

    def record_blocks
      @records.map { |fields| "#{UsageRecords.begin_mark(fields)}\nshaka usage record\n#{UsageRecords::END_MARK}" }
    end
  end
end
