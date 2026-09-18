# frozen_string_literal: true

require_relative '../error'
require_relative '../repository_config'
require_relative '../trusted_config_source'

module Shaka
  class Snapshot
    # Answers whether this repository lets unfinished work leave the machine.
    #
    # The answer comes from the trusted default branch, so a candidate checkout cannot
    # widen its own boundary. A repository with no seam has said nothing, so the default
    # applies, and a seam that cannot be read refuses: publishing is irreversible.
    class Policy
      def initialize(root:, remote:)
        @root = root
        @remote = remote
      end

      def allows_snapshot?
        source = seam
        return true if source.nil?

        RepositoryConfig.new(root: @root, source: source).load.recovery.fetch('snapshot')
      end

      private

      def seam
        base = RepositoryConfig.load(root: @root).base_branch
        TrustedConfigSource.new(root: @root).read("#{@remote}/#{base}")
      rescue Shaka::Error, SystemCallError
        local
      end

      def local
        path = File.join(@root, RepositoryConfig::PATH)
        File.exist?(path) ? File.read(path, encoding: 'UTF-8') : nil
      end
    end
  end
end
