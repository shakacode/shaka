# frozen_string_literal: true

require_relative '../defaults'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates when a code walkthrough is published: only on request, or on every PR.
    class WalkthroughSchema
      include Validation

      KEY = 'publish'
      VALUES = %w[on_request always].freeze

      # A missing or unreadable configuration takes the packaged default.
      def self.publish(config) = config&.walkthrough&.fetch(KEY) || Defaults.fetch('walkthrough', KEY)

      # Loading the configuration validates the section here, beside its default.
      def self.resolve(walkthrough)
        new(walkthrough).validate
        { KEY => walkthrough.fetch(KEY) { Defaults.fetch('walkthrough', KEY) } }
      end

      def initialize(walkthrough)
        @walkthrough = walkthrough
      end

      def validate
        mapping!(@walkthrough, 'walkthrough')
        keys!(@walkthrough, [], [KEY], 'walkthrough')
        return unless @walkthrough.key?(KEY)

        enum!(@walkthrough[KEY], VALUES, "walkthrough.#{KEY} must be one of: #{VALUES.join(', ')}")
      end
    end
  end
end
