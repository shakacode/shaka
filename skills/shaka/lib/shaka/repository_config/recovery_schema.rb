# frozen_string_literal: true

require_relative '../error'

module Shaka
  class RepositoryConfig
    # Validates the optional recovery-note policy.
    class RecoverySchema
      KEYS = %w[workspace_path snapshot].freeze

      def initialize(recovery)
        @recovery = recovery
      end

      def validate
        raise Error, 'recovery must be a mapping' unless @recovery.is_a?(Hash) && @recovery.keys.all?(String)

        unknown = @recovery.keys - KEYS
        raise Error, "unknown key: #{unknown.first}" unless unknown.empty?

        @recovery.each do |key, value|
          raise Error, "recovery.#{key} must be true or false" unless [true, false].include?(value)
        end
      end
    end
  end
end
