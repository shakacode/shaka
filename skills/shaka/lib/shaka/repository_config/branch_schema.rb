# frozen_string_literal: true

require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional feature-branch layout.
    class BranchSchema
      include Validation

      PLACEHOLDERS = %w[login host issue description].freeze

      def initialize(data)
        @data = data
      end

      def validate
        mapping = require_mapping
        name = require_name(mapping)
        raise Error, 'branches.name must include {issue}' unless name.include?('{issue}')

        leftover = name.scan(/\{([^{}]+)\}/).flatten - PLACEHOLDERS
        raise Error, "branches.name has unknown placeholder: #{leftover.first}" unless leftover.empty?
      end

      private

      def require_mapping
        raise Error, 'branches must be a mapping' unless @data.is_a?(Hash) && @data.keys.all?(String)

        @data
      end

      def require_name(mapping)
        extra = mapping.keys - ['name']
        raise Error, "unknown key: #{extra.first}" unless extra.empty?
        raise Error, 'missing branches key: name' unless mapping.key?('name')

        string!(mapping['name'], 'branches.name')
      end
    end
  end
end
