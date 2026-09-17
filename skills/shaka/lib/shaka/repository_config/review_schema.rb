# frozen_string_literal: true

require_relative '../error'

module Shaka
  class RepositoryConfig
    # Validates the reviewer identity and trigger policy.
    class ReviewSchema
      STRING_FIELDS = %w[check model_family provider].freeze
      FIELDS = [*STRING_FIELDS, 'draft'].freeze

      def initialize(review)
        @review = review
      end

      def validate
        required = @review['required']
        enum!(required)
        return reject_policy if required == 'none'

        require_policy
      end

      private

      def enum!(value)
        allowed = %w[always meaningful_changes none]
        return if allowed.include?(value)

        raise Error, 'review.required must be always, meaningful_changes, or none'
      end

      def reject_policy
        extra = FIELDS.find { |key| @review.key?(key) }
        raise Error, "review.#{extra} must be omitted when review.required is none" if extra
      end

      def require_policy
        missing = FIELDS.find { |key| !@review.key?(key) }
        raise Error, "missing review key: #{missing}" if missing

        STRING_FIELDS.each { |key| string!(@review[key], "review.#{key}") }
        return if [true, false].include?(@review['draft'])

        raise Error, 'review.draft must be true or false'
      end

      def string!(value, label)
        raise Error, "#{label} must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?
      end
    end
  end
end
