# frozen_string_literal: true

require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional recovery-note policy.
    class RecoverySchema
      include Validation

      KEYS = %w[publish_locations].freeze

      def initialize(recovery)
        @recovery = recovery
      end

      def validate
        mapping!(@recovery, 'recovery')
        if @recovery.key?('workspace_path')
          raise Error, 'recovery.workspace_path was renamed to recovery.publish_locations; keep its boolean value'
        end

        keys!(@recovery, [], KEYS, 'recovery')
        @recovery.each do |key, value|
          enum!(value, [true, false], "recovery.#{key} must be true or false")
        end
      end
    end
  end
end
