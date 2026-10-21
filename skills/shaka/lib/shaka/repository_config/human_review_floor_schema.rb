# frozen_string_literal: true

require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the human review floors a repository sets for its PR descriptions.
    class HumanReviewFloorSchema
      include Validation

      LABEL = 'pr_description.human_review_floors'
      MATCHERS = %w[paths words].freeze
      LISTS = [*MATCHERS, 'except'].freeze

      def initialize(floors)
        @floors = floors
      end

      def validate
        raise Error, "#{LABEL} must be a list" unless @floors.is_a?(Array)

        @floors.each_with_index { |floor, index| validate_floor(floor, "#{LABEL}[#{index}]") }
      end

      private

      def validate_floor(floor, label)
        mapping!(floor, label)
        keys!(floor, %w[level reason], LISTS, label)
        enum!(floor['level'], (1..5).to_a, "#{label}.level must be a whole number from 1 to 5")
        string!(floor['reason'], "#{label}.reason")
        raise Error, "#{label} needs paths or words" unless floor.keys.intersect?(MATCHERS)

        (floor.keys & LISTS).each { |key| validate_list(floor[key], "#{label}.#{key}") }
      end

      def validate_list(values, label)
        raise Error, "#{label} must be a non-empty list" unless values.is_a?(Array) && !values.empty?

        values.each { |value| string!(value, "#{label} entry") }
      end
    end
  end
end
