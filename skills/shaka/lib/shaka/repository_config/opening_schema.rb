# frozen_string_literal: true

# Validates the optional opening-check settings in the repository contract.

require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates explicit consent and an optional trusted custom prompt path.
    class OpeningSchema
      include Validation

      def initialize(opening)
        @opening = opening
      end

      def validate
        mapping!(@opening, 'opening_check')
        keys!(@opening, [], %w[enabled prompt_file], 'opening_check')
        if @opening.key?('enabled')
          enum!(@opening['enabled'], [true, false], 'opening_check.enabled must be true or false')
        end
        return unless @opening.key?('prompt_file')

        prompt_path!(@opening['prompt_file'], 'opening_check.prompt_file')
      end
    end
  end
end
