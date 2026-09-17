# frozen_string_literal: true

require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the reviewer identity and trigger policy.
    class ReviewSchema
      include Validation

      STRING_FIELDS = %w[model_family provider].freeze
      METADATA_FIELDS = [*STRING_FIELDS, 'draft'].freeze

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
        super(value, allowed, 'review.required must be always, meaningful_changes, or none')
      end

      def reject_policy
        extra = ['check', *METADATA_FIELDS].find { |key| @review.key?(key) }
        raise Error, "review.#{extra} must be omitted when review.required is none" if extra
      end

      def require_policy
        string!(@review['check'], 'review.check')
        present = METADATA_FIELDS & @review.keys
        return if present.empty?

        missing = METADATA_FIELDS - @review.keys
        raise Error, "missing review key: #{missing.first}" unless missing.empty?

        STRING_FIELDS.each { |key| string!(@review[key], "review.#{key}") }
        return if [true, false].include?(@review['draft'])

        raise Error, 'review.draft must be true or false'
      end
    end
  end
end
