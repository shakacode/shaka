# frozen_string_literal: true

# Validates the optional opening-check settings in the repository contract.

require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates choices for the optional, separate check of a PR opening.
    class OpeningSchema
      include Validation

      DEFAULTS = { 'enabled' => true, 'effort' => 'low' }.freeze

      def self.effective(settings)
        DEFAULTS.merge(settings)
      end

      def initialize(opening)
        @opening = opening
      end

      def validate
        mapping!(@opening, 'opening_check')
        keys!(@opening, [], %w[enabled external_enabled reviewer model effort prompt_file], 'opening_check')
        validate_enabled
        validate_reviewer
        validate_model
        ReviewSchema.effort_level!(@opening['effort'], 'opening_check.effort') if @opening.key?('effort')
        return unless @opening.key?('prompt_file')

        prompt_path!(@opening['prompt_file'], 'opening_check.prompt_file')
      end

      private

      def validate_enabled
        if @opening.key?('enabled') && @opening.key?('external_enabled')
          raise Error, 'Use opening_check.enabled; omit its older name external_enabled'
        end

        %w[enabled external_enabled].each do |key|
          next unless @opening.key?(key)

          enum!(@opening[key], [true, false], "opening_check.#{key} must be true or false")
        end
      end

      def validate_reviewer
        return unless @opening.key?('reviewer')

        identity = ReviewerSelection.parse(@opening['reviewer']).values.map(&:downcase).join('/')
        return if ReviewerSelection::SUPPORTED_REVIEWERS.include?(identity)

        raise Error, 'opening_check.reviewer must be a supported provider/family'
      end

      def validate_model
        return unless @opening.key?('model')

        raise Error, 'opening_check.model requires opening_check.reviewer' unless @opening.key?('reviewer')

        ReviewSchema.model_name!(@opening['model'], 'opening_check.model')
      end
    end
  end
end
