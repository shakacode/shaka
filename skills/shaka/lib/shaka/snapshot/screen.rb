# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Snapshot
    # Decides which unfinished files may be published, because a push cannot be taken back.
    class Screen
      DENIED = [
        %r{(\A|/)\.env(\.|\z)},
        %r{(\A|/)\.netrc\z},
        %r{(\A|/)\.npmrc\z},
        %r{(\A|/)id_(rsa|dsa|ecdsa|ed25519)(\.|\z)},
        /\.(pem|key|p12|pfx|keystore|jks|ppk)\z/,
        %r{(\A|/)(credential|credentials|secret|secrets|service[-_]account)[^/]*\.(json|ya?ml|ini|txt)\z}i,
        /(secret|token|password|passwd|apikey|api[-_]key)/i
      ].freeze

      def initialize(paths)
        @paths = paths
      end

      def included = @paths - excluded

      def excluded = @paths.select { |path| DENIED.any? { |pattern| path.match?(pattern) } }
    end
  end
end
