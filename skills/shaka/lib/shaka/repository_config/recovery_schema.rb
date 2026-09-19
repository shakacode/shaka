# frozen_string_literal: true

require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional recovery-note policy.
    class RecoverySchema
      include Validation

      KEYS = %w[workspace_path snapshot].freeze

      def initialize(recovery)
        @recovery = recovery
      end

      def validate
        mapping!(@recovery, 'recovery')
        keys!(@recovery, [], KEYS, 'recovery')
        @recovery.each do |key, value|
          enum!(value, [true, false], "recovery.#{key} must be true or false")
        end
      end
    end
  end
end
