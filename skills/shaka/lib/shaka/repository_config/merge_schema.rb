# frozen_string_literal: true

require_relative '../error'
require_relative '../merge_limits'
require_relative '../merge_review_floor'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates merge authority, size limits, the Auto review floor or risk rule, hold labels, and the checks that
    # gate merge when GitHub enforces none.
    class MergeSchema
      include Validation

      REQUIRED_CHECKS = 'required_checks'
      REVIEW_FLOOR = 'auto_max_review_floor'
      HOLD_LABELS = 'hold_labels'
      AUTO_MERGE = 'auto_merge'
      AUTO_MERGE_VALUES = %w[floors low].freeze
      OPTIONAL = ['limits', REVIEW_FLOOR, AUTO_MERGE, REQUIRED_CHECKS, HOLD_LABELS].freeze

      def initialize(merge)
        @merge = merge
      end

      def validate
        mapping!(@merge, 'merge')
        retired = %w[method release].find { |key| @merge.key?(key) }
        raise Error, "merge.#{retired} is no longer configurable; see skills/shaka/references/migration.md" if retired

        keys!(@merge, ['preference'], OPTIONAL, 'merge')
        enum!(@merge['preference'], %w[ask auto], 'merge.preference must be ask or auto')
        MergeLimits.validate!(@merge['limits']) if @merge.key?('limits')
        MergeReviewFloor.validate!(@merge[REVIEW_FLOOR]) if @merge.key?(REVIEW_FLOOR)
        auto_merge!
        name_lists!
      end

      private

      def auto_merge!
        return unless @merge.key?(AUTO_MERGE)

        enum!(@merge[AUTO_MERGE], AUTO_MERGE_VALUES, 'merge.auto_merge must be floors or low')
      end

      def name_lists!
        { REQUIRED_CHECKS => 'check names', HOLD_LABELS => 'label names' }.each do |key, noun|
          name_list!(@merge[key], "merge.#{key}", noun) if @merge.key?(key)
        end
      end
    end
  end
end
