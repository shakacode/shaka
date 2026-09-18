# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Snapshot
    # Decides which unfinished files may be published, because a push cannot be taken back.
    #
    # It reads path names only. A credential pasted inside an ordinary file is invisible
    # here, which is why the command prints what it would publish before publishing it.
    class Screen
      DENIED = [
        %r{(\A|/)\.(env|netrc|npmrc|pgpass|git-credentials)(\.|\z)},
        %r{(\A|/)\.(aws|ssh|gnupg)/},
        %r{(\A|/)\.docker/config\.json\z},
        %r{(\A|/)id_(rsa|dsa|ecdsa|ed25519)(\.|\z)},
        /\.(pem|key|p12|pfx|keystore|jks|ppk)\z/,
        %r{(\A|/)(credential|credentials|secret|secrets|service[-_]account)[^/]*\z}i,
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
