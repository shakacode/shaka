# frozen_string_literal: true

require_relative '../evidence/verification'
require_relative '../evidence/public_settings'
require_relative '../repository_config'
require_relative 'feature_guard'
require_relative '../opening_publication'
require_relative 'settings_table'
require_relative 'run_summary'
require_relative 'review_effort_floor'

module Shaka
  # Consumes existing results; never stores a second receipt or rewrites an earlier one.
  class PublicationSettings
    SUMMARY = 'Shaka settings used'
    MISSING_REF = 'Withheld: settings not read; rerun description with --ref'
    UNAVAILABLE_SETTINGS = 'Withheld: settings unavailable; fix seam check --ref, then rerun description'

    def self.refuse_free_form!(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(SUMMARY) }

      raise Error, 'Shaka settings must come from validation/review results, not a details item.'
    end

    def self.prepare(root:, ref:, pull:, options:, github:)
      changed_paths = FeaturePublication.check(github:, pull:, flow: options.fetch(:publication_flow, 'feature'))
      repository = github.repository
      verdict = verify(root:, ref:, repository:, pull:, options:)
      current, floors = (current_settings(root:, ref:, repository:, required: !verdict.nil?) if ref)
      new(verdict:, current:, location_diagnostic: ref ? UNAVAILABLE_SETTINGS : MISSING_REF, repository:,
          review_effort_floor: ReviewEffortFloor.for(changed_paths, floors))
    end

    def self.verify(root:, ref:, repository:, pull:, options:)
      paths = { validation: options[:validation], review: options[:review] }
      return unless paths.values.any?
      raise Error, 'Settings publication requires --ref and --root' unless ref && options[:root]

      verdict = Evidence::Verification.new(root:, ref:, repository:, head: pull.dig('head', 'sha'), paths:).run
      return verdict if verdict['status'] == 'ready'

      raise Error, 'Settings evidence is missing or stale; rerun affected validation/review'
    end

    # Returns the public settings snapshot and the trusted review-effort floors.
    def self.current_settings(root:, ref:, repository:, required: false)
      OpeningPublication.with_safe_path(root:, select_gh: false) do |candidate_root|
        config, _settings, _kind, current = Evidence::Inputs.capture(root: candidate_root, ref:, repository:)
        [current, config.pr_description['human_review_floors']]
      end
    rescue Error, SystemCallError
      raise if required
    end

    def initialize(verdict: nil, current: nil, location_diagnostic: MISSING_REF, repository: nil,
                   review_effort_floor: nil)
      @review_effort_floor = review_effort_floor
      @repository = repository
      @verdict = verdict
      @current = current
      @location_diagnostic = location_diagnostic
    end

    # An unknown policy cannot authorize publishing the checkout path, even on unfinished PRs.
    def include_checkout_path? = @current&.fetch('wip.include_checkout_path', false) == true

    def path_redaction
      return if include_checkout_path?
      return 'REDACTED' if @current&.fetch('wip.include_checkout_path', nil) == false

      @location_diagnostic
    end

    # Only resolved settings can establish whether the repository opted out.
    def attribution? = @current&.fetch('pr_description.show_shaka_credit', false) == true

    # An unread setting leaves the list on: the agent passed a comment read for it, and leaving
    # the list out would hide what people wrote.
    def human_comments? = @current&.fetch('pr_description.show_human_comments', nil) != false

    def human_comment_rows
      rows = @current&.fetch('pr_description.max_human_comments', nil)
      rows.is_a?(Integer) && rows.positive? ? rows : RepositoryConfig::DEFAULT_PR_DESCRIPTION.fetch('max_human_comments')
    end

    # The bound results Verification reports and the floor the changed paths set; nil when not read.
    attr_reader :verdict, :review_effort_floor

    NOTE = 'Only the listed runs are covered. Selecting settings does not show that a check ran.'
    LOCAL_NOTE = 'Local files remain local; the values below are a report, not a backup. ' \
                 'Private trials default to asking before merge. A local merge preference cannot authorize merging; ' \
                 'user authorization and required GitHub checks still apply.'
    INSTALLATIONS = { 'revision' => 'installed revision', 'development' => 'development install',
                      'uninstalled' => 'no installation record', 'UNKNOWN' => 'installation source unavailable' }.freeze
    OPERATIONS = { 'validation' => 'Validation', 'review' => 'Review' }.freeze
    CURRENT = 'Current settings'
    # Settings from these sources are not readable in the repository, so the block keeps every value.
    UNCOMMITTED = %w[private/local preview/local].freeze

    def detail
      status = @verdict ? 'Recorded checks match this PR’s current commit.' :
                         'No matching check records supplied. Rerun missing validation or review to record them.'
      { 'summary' => SUMMARY, 'body' => [status, NOTE, current_line, *operations_table, *values].join("\n\n") }
    end

    private

    def current_line
      settings = Evidence::PublicSettings.sanitize(@current)
      version, installation = settings.values_at('installation.version', 'installation.source')
      shaka = "#{version} (#{INSTALLATIONS.fetch(installation, 'REDACTED')})"
      "#{CURRENT}: #{SettingsTable.source(settings, @repository)}; Shaka #{shaka}"
    end

    # One row per recorded result. Binding refuses a result whose settings differ from the
    # current ones, so a row needs only what can still vary: its revision and what it ran with.
    def operations_table
      rows = operations.map do |title, settings, run|
        [title, SettingsTable.source(settings, @repository), [ran_with(settings), run].compact.join(': ')]
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

    def ran_with(settings)
      command, reviewer, effort = settings.values_at('overrides.command', 'overrides.reviewer', 'overrides.effort')
      parts = [command, reviewer, ("#{effort} effort" unless effort == 'UNKNOWN')].compact - ['UNKNOWN']
      parts.empty? ? 'UNKNOWN' : parts.join(', ')
    end

    def values
      columns = operations.map { |title, settings| [column_title(title, settings), settings] }
      columns << [CURRENT, Evidence::PublicSettings.sanitize(@current)]
      return [] unless columns.any? { |_title, settings| UNCOMMITTED.include?(settings['source']) }

      [LOCAL_NOTE, SettingsTable.disclosure(columns)]
    end

    # Several reviewers would otherwise share one column title.
    def column_title(title, settings)
      reviewer = settings['overrides.reviewer']
      reviewer == 'UNKNOWN' ? title : "#{title}: #{reviewer}"
    end
  end
end
