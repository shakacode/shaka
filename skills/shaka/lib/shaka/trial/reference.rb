# frozen_string_literal: true

require_relative '../error'

module Shaka
  module Trial
    # The explicit upstream PR selection is separate from the target project's work item.
    module Reference
      REPOSITORY = 'shakacode/shaka'
      URL = %r{\Ahttps://github\.com/shakacode/shaka/pull/([1-9]\d*)\z}
      HEAD = /\A[0-9a-f]{40}\z/

      def self.number(url)
        URL.match(url.to_s)&.[](1) || raise(Error, 'Select a Shaka PR URL: https://github.com/shakacode/shaka/pull/N')
      end

      def self.head(value)
        return value if value.is_a?(String) && HEAD.match?(value)

        raise Error, 'Expected the full tested Shaka commit SHA.'
      end

      def self.public_candidate!(pull)
        return if pull.dig('base', 'repo', 'full_name') == REPOSITORY &&
                  pull.dig('base', 'repo', 'private') == false

        raise Error, 'Trial source must be the public shakacode/shaka repository.'
      end
    end
  end
end
