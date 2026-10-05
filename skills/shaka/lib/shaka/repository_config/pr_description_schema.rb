# frozen_string_literal: true

require_relative 'opening_schema'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates settings grouped by the PR description they affect.
    class PrDescriptionSchema
      include Validation

      def initialize(description)
        @description = description
      end

      def validate
        mapping!(@description, 'pr_description')
        keys!(@description, [], ['opening_check'], 'pr_description')
        return unless @description.key?('opening_check')

        OpeningSchema.new(@description['opening_check'], label: 'pr_description.opening_check').validate
      end
    end
  end
end
