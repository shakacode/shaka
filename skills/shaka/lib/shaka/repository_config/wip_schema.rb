# frozen_string_literal: true

require_relative '../defaults'
require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional WIP Details policy.
    class WipSchema
      include Validation

      KEY = 'include_checkout_path'

      def self.resolve(wip)
        { KEY => wip.fetch(KEY) { Defaults.fetch('wip', KEY) } }
      end

      def initialize(wip)
        @wip = wip
      end

      def validate
        mapping!(@wip, 'wip')
        keys!(@wip, [], [KEY], 'wip')
        @wip.each do |key, value|
          enum!(value, [true, false], "wip.#{key} must be true or false")
        end
      end
    end
  end
end
