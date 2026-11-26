# frozen_string_literal: true

require_relative '../error'
require_relative '../configuration/trust_config'

module Shaka
  module PublicComments
    # What a reply needs before it applies the author screen: whether the repository is public,
    # and the trust configuration from the default branch. Expects `@github`, `@trust_config`,
    # and `@machine_path`.
    module TrustLookup
      VISIBILITIES = %w[public private internal].freeze

      private

      def public?
        visibility = @github.api("repos/#{@github.repository}")['visibility']
        raise Error, 'Repository visibility is unavailable.' unless VISIBILITIES.include?(visibility)

        visibility == 'public'
      end

      def config
        return @trust_config if @trust_config

        loader = TrustConfig.new(@github, machine_path: @machine_path)
        @trust_config = loader.load(base_oid: loader.default_base_oid)
      end
    end
  end
end
