# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Renders the WIP Details note as one table, so every host publishes the same fields in the same shape.
  class WipDetails
    SUMMARY = 'WIP Details'
    FIELDS = {
      'owner' => 'Owner',
      'task' => 'Task',
      'thread' => 'Thread',
      'last_observed_activity' => 'Last observed activity',
      'revision' => 'Revision',
      'workspace' => 'Workspace',
      'unfinished_work' => 'Unfinished work',
      'stopped_because' => 'Stopped because',
      'merge_authority' => 'Merge authority',
      'state' => 'State',
      'next_action' => 'Next action'
    }.freeze

    NOTE = %r{<details>\n<summary>#{SUMMARY}</summary>\n\n(.*?)\n\n</details>}m

    # Reads the Revision cell back from a note this class rendered, or nil when the text holds no
    # complete note: a partial or reordered table was not written by this class.
    def self.revision(text)
      # A body saved from GitHub's web editor comes back with CRLF line endings.
      note = text.to_s.gsub("\r\n", "\n")[NOTE, 1] or return
      cells = rows(note)
      cells[FIELDS.keys.index('revision')].last if cells.map(&:first) == FIELDS.values
    end

    # Only text between one opening and one later closing marker is the helper's own; anyone who can
    # edit the body can write elsewhere in it.
    def self.managed_region(body, open_mark, close_mark)
      open = body.index(open_mark)
      close = body.index(close_mark)
      single = body.scan(open_mark).one? && body.scan(close_mark).one?
      return '' unless single && open < close

      body[(open + open_mark.length)...close]
    end

    def self.rows(note)
      note.lines.drop(2).map { |line| line.chomp.match(/\A\| (.+?) \| (.*) \|\z/)&.captures || [] }
    end

    def initialize(spec)
      @spec = spec
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

    # Escaping pipes keeps a value from silently adding a column; escaping backslashes first
    # keeps a value's own backslash from pairing with that escape.
    def cell(key)
      value = @spec[key]
      unless value.is_a?(String) && !value.strip.empty? && !value.match?(/[\r\n]/)
        raise Error, "Publication wip #{key} must be single-line nonempty text."
      end

      value.strip.gsub(/[\\|]/) { |character| "\\#{character}" }
    end
  end
end
