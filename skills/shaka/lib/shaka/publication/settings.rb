# frozen_string_literal: true

require_relative '../publication_settings'
require_relative 'settings_table'
require_relative 'run_summary'

module Shaka
  # Renders the Shaka settings used block from the results PublicationSettings verified.
  class PublicationSettings
    NOTE = 'Only the listed runs are covered. Selecting settings does not show that a check ran.'
    LOCAL_NOTE = 'Local files remain local; the values below are a report, not a backup. ' \
                 'Private trials default to asking before merge. A local merge preference cannot authorize merging; ' \
                 'user authorization and required GitHub checks still apply.'
    INSTALLATIONS = { 'revision' => 'installed revision', 'development' => 'development install',
                      'uninstalled' => 'no installation record', 'UNKNOWN' => 'installation source unavailable' }.freeze
    OPERATIONS = { 'validation' => 'Validation', 'review' => 'Review' }.freeze
    CURRENT = 'Current settings'
    # Execution details shows the skill version: its commit when known, otherwise the release.
    VERSION_POINTER = 'Shaka skill version under Execution details'
    # Settings from these sources are not readable in the repository, so the block keeps every value.
    UNCOMMITTED = %w[private/local preview/local].freeze
    MISSING_LINE = '**Shaka settings were missing:** this repository has no Shaka settings file, so this PR was ' \
                   'prepared without them. [Set up Shaka](https://shaka.shakacode.com/docs/getting-started#' \
                   '2-choose-individual-or-team-setup) to run its full workflow.'

    # A description adds this after its opening lines, above the summary, when the repository has no settings at
    # all. It reads the flag directly, so an installed settings object that predates it renders no line.
    def missing_lines = @missing == true ? [MISSING_LINE] : []

    def detail
      status = if @verdict&.key?('kept_line')
                 'Recorded checks kept from this commit’s earlier description; not rechecked.'
               elsif @verdict
                 ['Recorded checks match this PR’s current commit.', *review_not_required].join(' ')
               else
                 'No matching check records supplied. Rerun missing validation or review to record them.'
               end
      { 'summary' => SUMMARY, 'body' => [status, NOTE, current_line, *operations_table, *values].join("\n\n") }
    end

    # What prepare found when the bound reviews number fewer than the trusted settings configure,
    # the zone PR times are shown in, and the pull request template's headings.
    # Read here, beside the renderers a preview loads from the PR head, so an installed helper
    # that never sets them previews with no shortfall and the usual order instead of failing.
    attr_reader :reviewer_shortfall, :time_zone, :template_headings

    # EarlierReview's sentence when no results were supplied, or nil.
    attr_reader :earlier_review

    private

    def review_not_required
      ['This repository’s settings do not require review.'] if @verdict['review_required'] == false
    end

    def current_line
      settings = Evidence::PublicSettings.sanitize(@current)
      version, installation = settings.values_at('installation.version', 'installation.source')
      "#{CURRENT}: #{SettingsTable.source(settings, @repository)}; Shaka installation: version #{version}, " \
        "#{INSTALLATIONS.fetch(installation, 'REDACTED')} (#{VERSION_POINTER})"
    end

    # One row per recorded result. Binding refuses a result whose settings differ from the
    # current ones, so a row needs only what can still vary: its revision and what it ran with.
    def operations_table
      rows = operations.map do |title, settings, run|
        [title, SettingsTable.source(settings, @repository), [SettingsTable.ran_with(settings), run].compact.join(': ')]
      end
      return [] if rows.empty?

      lines = [['Step', 'Settings source', 'Run details'], %w[--- --- ---], *rows]
      [lines.map { |cells| "| #{cells.join(' | ')} |" }.join("\n")]
    end

    def operations
      OPERATIONS.flat_map do |kind, title|
        Array(@verdict&.dig('checks', kind)).map do |entry|
          [title, Evidence::PublicSettings.sanitize(entry.dig('original', 'public_settings')),
           RunSummary.render(entry['original'])]
        end
      end
    end

    def values
      columns = operations.map { |title, settings| [SettingsTable.column_title(title, settings), settings] }
      columns << [CURRENT, Evidence::PublicSettings.sanitize(@current)]
      return [] unless columns.any? { |_title, settings| UNCOMMITTED.include?(settings['source']) }

      [LOCAL_NOTE, SettingsTable.disclosure(columns)]
    end
  end
end
