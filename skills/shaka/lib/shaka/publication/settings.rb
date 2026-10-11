# frozen_string_literal: true

require_relative '../evidence/verification'
require_relative '../evidence/public_settings'
require_relative 'feature_guard'
require_relative '../opening_publication'

module Shaka
  # Consumes existing results; never stores a second receipt or rewrites an earlier one.
  class PublicationSettings
    SUMMARY = 'Shaka settings used'
    MISSING_REF = 'Withheld: settings not read; rerun description with --ref'
    UNAVAILABLE_SETTINGS = 'Withheld: settings unavailable; fix seam check --ref, then rerun description'

    def self.refuse_free_form!(items)
      return unless items.any? do |item|
        item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(SUMMARY)
      end

      raise Error, 'Shaka settings must come from validation/review results, not a details item.'
    end

    def self.prepare(root:, ref:, pull:, options:, github:)
      FeaturePublication.check(github:, pull:, flow: options.fetch(:publication_flow, 'feature'))
      repository = github.repository
      verdict = verify(root:, ref:, repository:, pull:, options:)
      current = current_settings(root:, ref:, repository:, required: !verdict.nil?) if ref
      new(verdict:, current:, location_diagnostic: ref ? UNAVAILABLE_SETTINGS : MISSING_REF)
    end

    def self.verify(root:, ref:, repository:, pull:, options:)
      paths = { validation: options[:validation], review: options[:review] }
      return unless paths.values.any?
      raise Error, 'Settings publication requires --ref and --root' unless ref && options[:root]

      verdict = Evidence::Verification.new(root:, ref:, repository:, head: pull.dig('head', 'sha'), paths:).run
      raise Error, 'Settings evidence is missing or stale; rerun affected validation/review' unless
        verdict['status'] == 'ready'

      verdict
    end

    def self.current_settings(root:, ref:, repository:, required: false)
      OpeningPublication.with_safe_path(root:, select_gh: false) do |candidate_root|
        _config, _settings, _kind, current = Evidence::Inputs.capture(root: candidate_root, ref:, repository:)
        current
      end
    rescue Error, SystemCallError
      raise if required

      nil
    end

    def initialize(verdict: nil, current: nil, location_diagnostic: MISSING_REF)
      @verdict = verdict
      @current = current
      @location_diagnostic = location_diagnostic
    end

    # An unknown policy cannot authorize publishing locations, even on unfinished PRs.
    def include_locations? = @current&.fetch('wip.include_locations', false) == true

    def location_redaction
      return if include_locations?
      return 'REDACTED' if @current&.fetch('wip.include_locations', nil) == false

      @location_diagnostic
    end

    # Only resolved settings can establish whether the repository opted out.
    def attribution? = @current&.fetch('pr_description.show_shaka_credit', false) == true

    NOTE = 'Local files remain local. This reports operation settings and cannot restore them. ' \
           'It does not prove earlier checks ran. Private merge.preference grants no Auto authority. ' \
           'Private trials default to Ask; explicit user authorization and live required gates govern merging.'
    COLUMNS = ['Before push: validation', 'Review', 'Current merge input (not evidence)'].freeze
    FOLDED = { 'UNKNOWN' => 'UNKNOWN in every column',
               'REDACTED' => 'Never published, so REDACTED in every column' }.freeze
    VALUES_SUMMARY = 'Setting values at validation, review, and merge'

    def detail
      status = @verdict ? 'Bound to the current candidate commit.' : 'UNKNOWN: rerun missing evidence.'
      { 'summary' => SUMMARY, 'body' => [status, NOTE, values].join("\n\n") }
    end

    private

    # A second disclosure keeps the status and note readable ahead of the long table.
    def values
      recorded, unrecorded = columns.partition { |_title, settings| settings.values.uniq != ['UNKNOWN'] }
      parts = [*unrecorded_note(unrecorded), *table(recorded)]
      "<details>\n<summary>#{VALUES_SUMMARY}</summary>\n\n#{parts.join("\n\n")}\n\n</details>"
    end

    def columns
      snapshots = %w[validation review].map { |kind| checked_snapshot(kind) } + [@current]
      COLUMNS.zip(snapshots.map { |snapshot| Evidence::PublicSettings.sanitize(snapshot) })
    end

    # A column no snapshot filled is named above the table instead of repeating UNKNOWN down it.
    def unrecorded_note(columns)
      titles = columns.map { |title, _settings| "**#{title}**" }.join(', ')
      columns.empty? ? [] : ["Not shown, because every setting is UNKNOWN there: #{titles}"]
    end

    def table(columns)
      return [] if columns.empty?

      rows = rows(columns).group_by { |field, cells| fold(field, cells) }
      lines = [['Setting', *columns.map(&:first)], ['---'] * (columns.size + 1), *rows.fetch(nil, []).map(&:flatten)]
      [lines.map { |cells| "| #{cells.join(' | ')} |" }.join("\n"), *folded_notes(rows)]
    end

    def rows(columns)
      Evidence::PublicSettings::FIELDS.map { |field| [field, columns.map { |_title, settings| settings[field] }] }
    end

    def folded_notes(rows)
      FOLDED.filter_map { |cell, lead| "#{lead}: #{rows[cell].map(&:first).join(', ')}" if rows.key?(cell) }
    end

    # A row that says the same nothing in every shown column is named on one line instead:
    # UNKNOWN throughout, or REDACTED throughout for a value the allowlist never publishes.
    # Any other row stays, so a cell that differs from its neighbours is always visible.
    def fold(field, cells)
      return 'UNKNOWN' if cells.all?('UNKNOWN')

      'REDACTED' if Evidence::PublicSettings::REDACTED.include?(field) && cells.all?('REDACTED')
    end

    def checked_snapshot(kind)
      entries = @verdict&.dig('checks', kind)
      snapshots = entries&.map { |entry| entry.dig('original', 'public_settings') }&.uniq
      snapshots&.size == 1 ? snapshots.first : nil
    end
  end
end
