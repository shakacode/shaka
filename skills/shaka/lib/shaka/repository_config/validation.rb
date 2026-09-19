# frozen_string_literal: true

require_relative '../error'

module Shaka
  class RepositoryConfig
    # Shared primitive validators for repository policy sections.
    module Validation
      private

      def string!(value, label)
        raise Error, "#{label} must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?

        value
      end

      def mapping!(value, label)
        raise Error, "#{label} must be a mapping" unless value.is_a?(Hash) && value.keys.all?(String)

        value
      end

      def keys!(mapping, required, optional, label)
        unknown = mapping.keys - required - optional
        missing = required - mapping.keys
        raise Error, "unknown key: #{unknown.first}" unless unknown.empty?
        raise Error, "missing #{label} key: #{missing.first}" unless missing.empty?
      end

      def enum!(value, allowed, message)
        raise Error, message unless allowed.include?(value)
      end
    end
  end
end
