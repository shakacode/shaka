# frozen_string_literal: true

require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional attribution choice for PR descriptions.
    class PrDescriptionSchema
      include Validation

      def initialize(description)
        @description = description
      end

      def validate
        mapping!(@description, 'pr_description')
        keys!(@description, [], ['attribution'], 'pr_description')
        return unless @description.key?('attribution')

        enum!(@description['attribution'], [true, false], 'pr_description.attribution must be true or false')
      end
    end
  end
end
