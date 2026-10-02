# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Renders the WIP Details note as one table, so every host publishes the same fields in the same shape.
  class WipDetails
    SUMMARY = 'WIP Details'
    FIELDS = {
      'owner' => 'Owner',
      'task' => 'Task',
      'thread' => 'Chat link',
      'last_observed_activity' => 'Last observed activity',
      'revision' => 'Revision',
      'workspace' => 'Workspace',
      'unfinished_work' => 'Unfinished work',
      'stopped_because' => 'Stopped because',
      'merge_authority' => 'Merge authority',
      'state' => 'State',
      'next_action' => 'Next action'
    }.freeze
    # Open notes published this heading before Chat link. Handoff still reads them.
    PREVIOUS_LABELS = FIELDS.merge('thread' => 'Thread').freeze
    RECOGNIZED_HEADINGS = [FIELDS.values, PREVIOUS_LABELS.values].freeze

    def initialize(spec, include_locations: true)
      @spec = spec
      @include_locations = include_locations
    end

    def detail
      { 'summary' => SUMMARY, 'body' => table }
    end

    private

    def table
      rows = validated.map { |key, value| [FIELDS.fetch(key), value] }
      ([%w[Field Value], %w[--- ---]] + rows).map { |row| "| #{row.join(' | ')} |" }.join("\n")
    end

    def validated
      raise Error, 'Publication wip must be an object.' unless @spec.is_a?(Hash)

      refuse_keys(@spec.keys - FIELDS.keys, 'has unknown fields')
      refuse_keys(FIELDS.keys - @spec.keys, 'is missing fields', '; use UNKNOWN')
      FIELDS.keys.to_h { |key| [key, cell(key)] }
    end

    def refuse_keys(keys, problem, advice = '')
      raise Error, "Publication wip #{problem}: #{keys.join(', ')}#{advice}." unless keys.empty?
    end

    def cell(key)
      return 'REDACTED' if !@include_locations && %w[workspace thread].include?(key)

      value = @spec[key]
      unless value.is_a?(String) && !value.strip.empty? && !value.match?(/[\r\n]/)
        raise Error, "Publication wip #{key} must be single-line nonempty text."
      end

      PublicationText.table_cell(value.strip)
    end
  end
end
