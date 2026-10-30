# frozen_string_literal: true

require_relative 'opening_schema'
require_relative 'human_review_floor_schema'
require_relative 'validation'
require_relative '../publication/time_zone'

module Shaka
  class RepositoryConfig
    # Validates settings grouped by the PR description they affect.
    class PrDescriptionSchema
      include Validation

      KEYS = %w[show_shaka_credit show_human_comments max_human_comments time_zone opening_check
                human_review_floors].freeze

      def initialize(description)
        @description = description
      end

      def validate
        mapping!(@description, 'pr_description')
        keys!(@description, [], KEYS, 'pr_description')
        validate_credit
        validate_human_comments
        validate_time_zone
        HumanReviewFloorSchema.new(@description['human_review_floors']).validate if
          @description.key?('human_review_floors')
        return unless @description.key?('opening_check')

        OpeningSchema.new(@description['opening_check']).validate
      end

      private

      def validate_credit
        return unless @description.key?('show_shaka_credit')

        enum!(@description['show_shaka_credit'], [true, false],
              'pr_description.show_shaka_credit must be true or false')
      end

      def validate_human_comments
        shown = @description.fetch('show_human_comments', true)
        enum!(shown, [true, false], 'pr_description.show_human_comments must be true or false')
        rows = @description.fetch('max_human_comments', 1)
        return if rows.is_a?(Integer) && rows.positive?

        raise Error, 'pr_description.max_human_comments must be a positive integer'
      end

      def validate_time_zone
        TimeZone.validate!(@description['time_zone'], 'pr_description.time_zone') if @description.key?('time_zone')
      end
    end
  end
end
