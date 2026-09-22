# frozen_string_literal: true

require_relative '../error'
require_relative '../review_pace'
require_relative '../reviewer_selection'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the ordered reviewer preference list and trigger policy.
    class ReviewSchema
      include Validation

      # The validator enforces exactly what selection consumes, so both read one definition.
      IDENTITY = ReviewerSelection::IDENTITY
      GITHUB_ACTION_CHECK = 'github_action_check'
      LOCAL_REVIEWERS = 'local_reviewers'
      RENAMED = { 'check' => GITHUB_ACTION_CHECK, 'reviewers' => LOCAL_REVIEWERS }.freeze
      RETIRED = %w[model_family provider draft].freeze

      # The flat metadata group became an ordered list, so name the migration rather than
      # reporting an unknown key at a seam the previous release accepted.
      def self.retired!(review)
        found = RETIRED & review.keys
        return if found.empty?

        raise Error, "review.#{found.first} moved into review.#{LOCAL_REVIEWERS}; see docs/settings.md"
      end

      # `check` and `reviewers` did not say which list was the GitHub Action and which was local.
      def self.renamed!(review)
        old = RENAMED.keys.find { |key| review.key?(key) }
        return unless old

        raise Error, "review.#{old} moved to review.#{RENAMED.fetch(old)}; see docs/settings.md"
      end

      def initialize(review)
        @review = review
      end

      # A seam with no native gate still declares its reviewer order, because
      # `required: none` drops the repository's named check, not the alternate-review baseline.
      def validate
        enum!(@review['required'])
        validate_check
        validate_pace
        local_reviewers!(@review[LOCAL_REVIEWERS]) if @review.key?(LOCAL_REVIEWERS)
      end

      private

      def enum!(value)
        allowed = %w[always meaningful_changes none]
        super(value, allowed, 'review.required must be always, meaningful_changes, or none')
      end

      def validate_check
        key = GITHUB_ACTION_CHECK
        return string!(@review[key], "review.#{key}") unless @review['required'] == 'none'
        return unless @review.key?(key)

        raise Error, "review.#{key} must be omitted when review.required is none"
      end

      def validate_pace
        return unless @review.key?('pace')
        raise Error, 'review.pace must be swift or thorough' unless ReviewPace::VALUES.include?(@review['pace'])
      end

      def local_reviewers!(reviewers)
        label = "review.#{LOCAL_REVIEWERS}"
        raise Error, "#{label} must be a list" unless reviewers.is_a?(Array)
        raise Error, "#{label} must not be empty" if reviewers.empty?

        reviewers.each_with_index { |entry, index| entry!(entry, index) }
        repeated!(reviewers)
      end

      # Selection folds case when it compares identities, so two spellings of one identity must
      # not both validate here.
      def repeated!(reviewers)
        identities = reviewers.map { |entry| entry.values_at(*IDENTITY).map(&:downcase) }
        repeated = identities.tally.find { |_, count| count > 1 }
        raise Error, "review.#{LOCAL_REVIEWERS} repeats #{repeated.first.join('/')}" if repeated
      end

      def entry!(entry, index)
        label = "review.#{LOCAL_REVIEWERS}[#{index}]"
        mapping!(entry, label)
        keys!(entry, IDENTITY, [], label)
        IDENTITY.each { |key| component!(entry[key], "#{label}.#{key}") }
      end

      # `shaka reviewer` reads identities as PROVIDER/MODEL_FAMILY and strips each part, so a
      # padded or slash-bearing value here would not match the identity the agent passes and a
      # contributing family could pass as eligible.
      def component!(value, label)
        string!(value, label)
        raise Error, "#{label} must not contain '/'" if value.include?('/')
        raise Error, "#{label} must not start or end with whitespace" if value != value.strip
      end
    end
  end
end
