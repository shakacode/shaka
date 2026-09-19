# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Snapshot
    # Decides which unfinished files may be published, because a push cannot be taken back.
    #
    # It reads path names only, and every segment of them, because a directory names its
    # contents as surely as a file names itself. A credential pasted inside an ordinary file
    # is invisible here, which is why the command prints what it would publish first.
    class Screen
      DENIED = [
        %r{(\A|/|\.)env(\.|/|\z)}i,
        %r{(\A|/)\.(netrc|npmrc|pgpass|git-credentials)(\.|\z)}i,
        %r{(\A|/)\.(aws|ssh|gnupg)/}i,
        %r{(\A|/)\.docker/config\.json\z}i,
        %r{(\A|/)id_(rsa|dsa|ecdsa|ed25519)(\.|\z)}i,
        /\.(pem|key|p12|pfx|keystore|jks|ppk)\z/i,
        %r{(\A|/)(credential|secret|service[-_]account)[^/]*(/|\z)}i,
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
