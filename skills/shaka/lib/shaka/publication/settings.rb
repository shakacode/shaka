# frozen_string_literal: true

require_relative '../evidence/verification'
require_relative '../evidence/public_settings'
require_relative 'feature_guard'

module Shaka
  # Consumes existing results; never stores a second receipt or rewrites an earlier one.
  class PublicationSettings
    SUMMARY = 'Shaka settings used'

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
      current = current_settings(root:, ref:, repository:) if ref
      new(verdict:, current:)
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

    def self.current_settings(root:, ref:, repository:)
      _config, _settings, _kind, current = Evidence::Inputs.capture(root:, ref:, repository:)
      current
    end

    def initialize(verdict: nil, current: nil)
      @verdict = verdict
      @current = current
    end

    # An unknown policy cannot authorize publishing locations, even on unfinished PRs.
    def include_locations? = @current&.fetch('wip.include_locations', false) == true

    def rows
      snapshots = %w[validation review].map { |kind| checked_snapshot(kind) } + [@current]
      safe = snapshots.map { |snapshot| Evidence::PublicSettings.sanitize(snapshot) }
      Evidence::PublicSettings::FIELDS.map do |field|
        "| #{field} | #{safe.map { |snapshot| snapshot[field] }.join(' | ')} |"
      end
    end

    NOTE = 'Local files remain local. This reports operation settings and cannot restore them. ' \
           'It does not prove earlier checks ran. Private merge.preference grants no Auto authority. ' \
           'Private trials default to Ask; explicit user authorization and live required gates govern merging.'
    HEADER = '| Setting | Before push: validation | Review | Current merge input (not evidence) |'

    def detail
      status = @verdict ? 'Bound to the current candidate commit.' : 'UNKNOWN: rerun missing evidence.'
      table = [HEADER, '| --- | --- | --- | --- |', *rows].join("\n")
      { 'summary' => SUMMARY, 'body' => [status, NOTE, table].join("\n\n") }
    end

    private

    def checked_snapshot(kind)
      entries = @verdict&.dig('checks', kind)
      snapshots = entries&.map { |entry| entry.dig('original', 'public_settings') }&.uniq
      snapshots&.size == 1 ? snapshots.first : nil
    end
  end
end
