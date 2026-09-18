# frozen_string_literal: true

require_relative '../error'
require_relative '../repository_config'
require_relative '../trusted_config_source'

module Shaka
  class Snapshot
    # Answers whether this repository lets unfinished work leave the machine.
    #
    # The answer comes from the trusted default branch, so a candidate checkout cannot
    # widen its own boundary. A repository with no seam at all has said nothing, so the
    # default applies. Once a seam exists, a trusted copy that cannot be read refuses,
    # because the checkout's own copy could say anything and publishing is irreversible.
    class Policy
      def initialize(root:, remote:)
        @root = root
        @remote = remote
      end

      def allows_snapshot?
        return true unless seam_exists?

        source = trusted
        raise Error, "Cannot read #{RepositoryConfig::PATH} from #{@remote}; snapshots refuse." if source.nil?

        RepositoryConfig.new(root: @root, source: source).load.recovery.fetch('snapshot')
      end

      private

      def seam_exists? = File.exist?(File.join(@root, RepositoryConfig::PATH))

      # The branch name comes from the checkout, but only as a place to look: every
      # candidate ref is a trusted remote ref, and the answer is read from there.
      def trusted
        refs.each do |ref|
          return TrustedConfigSource.new(root: @root).read(ref)
        rescue Shaka::Error, SystemCallError
          next
        end
        nil
      end

      def refs
        ["#{@remote}/HEAD", *candidate_base].uniq
      end

      def candidate_base
        base = RepositoryConfig.load(root: @root).base_branch
        base.match?(%r{\A[\w.\-/]+\z}) ? ["#{@remote}/#{base}"] : []
      rescue Shaka::Error, SystemCallError
        []
      end
    end
  end
end
