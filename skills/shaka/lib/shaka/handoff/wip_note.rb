# frozen_string_literal: true

require_relative '../publication/publishing'
require_relative '../publication/wip_details'

module Shaka
  class Handoff
    # Reads back the WIP Details note that `description` published, from the description's managed region.
    module WipNote
      NOTE = %r{<details>\n<summary>#{WipDetails::SUMMARY}</summary>\n\n(.*?)\n\n</details>}m
      ROW = /\A\| (.+?) \| (.*) \|\z/

      module_function

      # The Revision cell of a complete note, or nil when the body holds none.
      def revision(body)
        value(body, 'revision')
      end

      def extract(body)
        # A body saved from GitHub's web editor comes back with CRLF line endings.
        region = Publishing.managed_region(body.to_s.gsub("\r\n", "\n")).to_s
        region[NOTE, 1]
      end

      def problem(body)
        owner = value(body, 'owner')
        WipDetails.owner_error(owner) ||
          WipMetadata.handoff_problem(extract(body), owner:, thread: value(body, 'thread'))
      end

      def value(body, field)
        cell = cells(extract(body))&.fetch(WipDetails::FIELDS.keys.index(field))
        PublicationText.table_cell_text(cell) unless cell.to_s.strip.empty?
      end

      # The Value column in field order, or nil for a partial or reordered table WipDetails did not render.
      # A collection record may follow the table; it is not another field row.
      def cells(note)
        rows = field_rows(note)
        rows.map(&:last) if rows&.map(&:first) == WipDetails::FIELDS.values
      end

      def field_rows(note)
        lines = note.to_s.lines.map(&:chomp)
        return unless lines.first(2) == ['| Field | Value |', '| --- | --- |']

        lines.drop(2).first(WipDetails::FIELDS.size).map { |line| line.match(ROW)&.captures || [] }
      end

      # Revision reads `BRANCH @ SHA`; only the part after the last ` @ ` is the head, whatever the branch is named.
      def head(revision) = revision.to_s.split(' @ ').last.to_s.strip
    end
  end
end
