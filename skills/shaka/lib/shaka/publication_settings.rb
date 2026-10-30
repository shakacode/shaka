# frozen_string_literal: true

require_relative 'evidence/verification'
require_relative 'evidence/public_settings'
require_relative 'repository_config'
require_relative 'publication/feature_guard'
require_relative 'opening_publication'
require_relative 'publication/review_effort_floor'
require_relative 'review_coverage'
require_relative 'local_review/ledger'

module Shaka
  # Consumes existing results; never stores a second receipt or rewrites an earlier one.
  # Reading, verification, and publication policy live outside publication/, whose renderers a
  # rendering preview loads from the PR head. publication/settings.rb renders the block.
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
      current, floors, review, config = (current_settings(root:, ref:, repository:, required: !verdict.nil?) if ref)
      new(verdict:, current:, location_diagnostic: ref ? UNAVAILABLE_SETTINGS : MISSING_REF, repository:,
          review_effort_floor: ReviewEffortFloor.for(changed_paths, floors),
          reviewer_shortfall: reviewer_shortfall(verdict, review), time_zone: config&.time_zone)
    end

    def self.verify(root:, ref:, repository:, pull:, options:)
      paths = { validation: options[:validation], review: options[:review] }
      return unless paths.values.any?
      raise Error, 'Settings publication requires --ref and --root' unless ref && options[:root]

      verdict = Evidence::Verification.new(root:, ref:, repository:, head: pull.dig('head', 'sha'), paths:).run
      raise Error, 'Settings evidence is missing or stale; rerun affected validation/review' unless
        verdict['status'] == 'ready'

      omitted_reviewers!(verdict)
      verdict
    end

    # A review run's result names its ledger round. Every reviewer of that round's batch read the same
    # commit under the same settings, so leaving one's result out would publish it as not reviewing.
    def self.omitted_reviewers!(verdict)
      results = Array(verdict.dig('checks', 'review')).map { |entry| entry['original'] }
      omitted = results.flat_map { |result| batch_reviewers(result) }.uniq -
                results.map { |result| result['reviewer'].to_s.downcase }
      return if omitted.empty?

      raise Error, "#{omitted.join(', ')} also reviewed this commit in the review ledger; pass each " \
                   "reviewer's saved result with its own --review-result. For a lost result, run " \
                   '`review check` with that reviewer and its report from the ledger.'
    end

    # Reviewer ids fold case, as the ledger compares them.
    def self.batch_reviewers(result)
      ledger = result['ledger']
      return [] unless ledger.is_a?(String) && File.file?(ledger)

      LocalReviewLedger.new(ledger).batch_reviewers(result['round'], head: result['head'],
                                                                     reviewer: result['reviewer']).map(&:downcase)
    end

    # Returns the public settings snapshot, the trusted review-effort floors, the trusted review
    # settings, and the loaded settings. A bad personal time zone must not lose the first three.
    def self.current_settings(root:, ref:, repository:, required: false)
      OpeningPublication.with_safe_path(root:, select_gh: false) do |candidate_root|
        config, _settings, _kind, current = Evidence::Inputs.capture(root: candidate_root, ref:, repository:)
        [current, config.pr_description['human_review_floors'], config.review, config]
      end
    rescue Error, SystemCallError
      raise if required
    end

    # Only a completed or host-reported review reaches a ready verdict, so each bound one counts.
    # A repository that requires no review falls short only when a review was run anyway.
    def self.reviewer_shortfall(verdict, review)
      return unless verdict && review

      reviewers = Array(verdict.dig('checks', 'review')).filter_map { |entry| entry.dig('original', 'reviewer') }
      return if reviewers.empty? && verdict['review_required'] == false

      ReviewCoverage.shortfall(review, reviewers)
    end

    def initialize(verdict: nil, current: nil, location_diagnostic: MISSING_REF, repository: nil, # rubocop:disable Metrics/ParameterLists
                   review_effort_floor: nil, reviewer_shortfall: nil, time_zone: nil)
      @reviewer_shortfall = reviewer_shortfall
      @time_zone = time_zone
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
  end
end
