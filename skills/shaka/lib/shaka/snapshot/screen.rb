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
        %r{(\A|[/._-])env([./_-]|\z)}i,
        %r{(\A|/)\.(netrc|npmrc|pgpass|git-credentials)(\.|\z)}i,
        %r{(\A|/)\.(aws|ssh|gnupg)/}i,
        %r{(\A|/)\.docker/config\.json\z}i,
        %r{(\A|/)id_(rsa|dsa|ecdsa|ed25519)(\.|\z)}i,
        /\.(pem|key|p12|pfx|keystore|jks|ppk)\z/i,
        %r{(\A|/)\.kube/}i,
        /\.tfstate(\.|\z)/i,
        /(credential|secret|token|password|passwd|apikey|api[-_]key|kubeconfig|adminsdk)/i,
        /service[-_]?account/i
      ].freeze

      def initialize(paths)
        @paths = paths
      end

      def included = @paths - excluded

      def excluded = @paths.select { |path| denied?(path) }

      private

      # A name the plan cannot render is a name nobody can review, and the printed plan is
      # what makes this safe. So a path that is not valid UTF-8 is held back rather than
      # matched against patterns it would raise on.
      def denied?(path)
        return true unless path.valid_encoding?

        DENIED.any? { |pattern| path.match?(pattern) }
      end
    end
  end
end
