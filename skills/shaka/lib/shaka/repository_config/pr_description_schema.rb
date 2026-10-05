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
        keys!(@description, [], ['show_shaka_credit'], 'pr_description')
        return unless @description.key?('show_shaka_credit')

        enum!(@description['show_shaka_credit'], [true, false],
              'pr_description.show_shaka_credit must be true or false')
      end
    end
  end
end
