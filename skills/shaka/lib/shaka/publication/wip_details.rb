# frozen_string_literal: true

require_relative '../error'
require_relative 'text'
require_relative 'wip_metadata'

module Shaka
  # Renders the WIP Details note as one table, so every host publishes the same fields in the same shape.
  class WipDetails
    SUMMARY = 'WIP Details'
    FIELDS = {
      'owner' => 'Owner',
      'task' => 'Chat name',
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

    # Shared with handoff, which reads the final GitHub note rather than trusting publication inputs.
    def self.owner_error(value)
      return if value == 'UNKNOWN'

      parts = value.to_s.split('·', -1).map(&:strip)
      return if parts.length == 3 && parts.none?(&:empty?) && !value.to_s.match?(/[\r\n]/)

      'WIP Owner must be machine alias · host · owner tag; use UNKNOWN for unavailable information.'
    end

    def initialize(spec, path_redaction: nil, session: {})
      @spec = spec
      @path_redaction = path_redaction
      @session = session
    end

    def detail
      { 'summary' => SUMMARY, 'body' => "#{table}\n\n#{@collection}" }
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
      checked_owner(FIELDS.keys.to_h { |key| [key, cell(key)] })
    end

    def checked_owner(cells)
      problem = self.class.owner_error(cells.fetch('owner'))
      raise Error, problem if problem

      @collection = WipMetadata.record(cells.fetch('owner'), cells.fetch('thread'), **session_arguments)
      cells
    end

    def refuse_keys(keys, problem, advice = '')
      raise Error, "Publication wip #{problem}: #{keys.join(', ')}#{advice}." unless keys.empty?
    end

    def session_arguments
      { environment: @session[:environment], disclosure: @session[:disclosure], host_name: @session[:host_name],
        previous: @session[:previous] || previous_note }
    end

    def previous_note
      body = @session[:pull].is_a?(Hash) ? @session[:pull]['body'] : nil
      return {} unless body

      { 'owner' => Handoff::WipNote.value(body, 'owner'), 'thread' => Handoff::WipNote.value(body, 'thread') }
    end

    def cell(key)
      return @path_redaction if @path_redaction && key == 'workspace'

      value = @spec[key]
      unless value.is_a?(String) && !value.strip.empty? && !value.match?(/[\r\n]/)
        raise Error, "Publication wip #{key} must be single-line nonempty text."
      end

      PublicationText.table_cell(value.strip)
    end
  end
end
