# frozen_string_literal: true

# Validates the optional opening-check settings in the repository contract.

require_relative 'review_schema'
require_relative 'validation'
require_relative '../defaults'
require_relative '../local_review/openrouter'

module Shaka
  class RepositoryConfig
    # Validates choices for the optional, separate check of a PR opening.
    class OpeningSchema
      include Validation

      DEFAULTS = Defaults.fetch('pr_description', 'opening_check')
      KEYS = ['enabled', 'reviewer', 'model', 'effort', ReviewSchema::PROMPT_FILE].freeze

      def self.effective(settings)
        DEFAULTS.merge(settings)
      end

      def initialize(opening, label: 'pr_description.opening_check')
        @opening = opening
        @label = label
      end

      def validate
        mapping!(@opening, @label)
        renamed_prompt_file!(@opening, @label)
        keys!(@opening, [], KEYS, @label)
        validate_enabled
        validate_reviewer
        validate_model
        ReviewSchema.effort_level!(@opening['effort'], "#{@label}.effort") if @opening.key?('effort')
        validate_provider_options
        return unless @opening.key?(ReviewSchema::PROMPT_FILE)

        prompt_path!(@opening[ReviewSchema::PROMPT_FILE], "#{@label}.#{ReviewSchema::PROMPT_FILE}")
      end

      private

      def validate_enabled
        return unless @opening.key?('enabled')

        enum!(@opening['enabled'], [true, false], "#{@label}.enabled must be true or false")
      end

      def validate_reviewer
        return unless @opening.key?('reviewer')

        @reviewer = ReviewerSelection.parse(@opening['reviewer']).values.map(&:downcase).join('/')
        return if ReviewerSelection::SUPPORTED_REVIEWERS.include?(@reviewer)

        raise Error, "#{@label}.reviewer must be a supported provider/family"
      end

      def validate_model
        return unless @opening.key?('model')

        raise Error, "#{@label}.model requires #{@label}.reviewer" unless @opening.key?('reviewer')

        ReviewSchema.model_name!(@opening['model'], "#{@label}.model")
      end

      def validate_provider_options
        if @reviewer == 'xai/grok' && !@opening.key?('model')
          raise Error, "#{@label}.model is required for xai/grok; its CLI has no default model"
        end
        return unless @reviewer == 'deepseek/openrouter'

        OpenrouterReview.validate!(model: @opening['model'], effort: @opening['effort'])
      rescue Error => e
        raise Error, "#{@label}: #{e.message}"
      end
    end
  end
end
