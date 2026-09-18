# frozen_string_literal: true

require_relative '../error'
require_relative '../repository_config'

module Shaka
  class Snapshot
    # Answers whether this repository lets unfinished work leave the machine.
    #
    # Both the question and the answer come from the trusted remote branch, so a candidate
    # checkout can neither rewrite the setting nor delete the seam to escape it. When a
    # remote exists but its seam cannot be read, publishing refuses: the checkout's own
    # copy could say anything, and a push cannot be taken back. A repository with no remote
    # has nowhere to publish, so it is left alone.
    class Policy
      NO_SEAM = :no_seam

      def initialize(root:, remote:, git:)
        @root = root
        @remote = remote
        @git = git
      end

      def allows_snapshot?
        return true unless remote?

        source = trusted
        raise Error, "Cannot read the trusted seam from #{@remote}; snapshots refuse." if source.nil?
        return true if source == NO_SEAM

        RepositoryConfig.new(root: @root, source: source).load.recovery.fetch('snapshot')
      end

      private

      def remote? = !@git.call('remote').split("\n").empty?

      # The checkout may name its base branch, but every ref consulted is a remote one.
      # When none is present, the remote itself is asked once: a remote with no branches
      # has no seam, while a remote that cannot be reached leaves the answer unknown.
      def trusted
        found = from_refs
        return found unless found.nil?

        return nil unless fetched?

        from_refs || NO_SEAM
      end

      def from_refs
        refs.each do |ref|
          next unless resolves?(ref)

          return read(ref)
        end
        nil
      end

      def fetched?
        @git.call('fetch', '--quiet', @remote, "+refs/heads/*:refs/remotes/#{@remote}/*")
        true
      rescue Error
        false
      end

      def refs = ["#{@remote}/HEAD", *candidate_base].uniq

      def candidate_base
        base = RepositoryConfig.load(root: @root).base_branch
        base.match?(%r{\A[\w.\-/]+\z}) ? ["#{@remote}/#{base}"] : []
      rescue Shaka::Error, SystemCallError
        []
      end

      def resolves?(ref)
        @git.call('rev-parse', '--verify', '--end-of-options', "#{ref}^{commit}")
        true
      rescue Error
        false
      end

      # A trusted branch that resolves but carries no seam means the repository has none.
      def read(ref)
        @git.call('show', "#{ref}:#{RepositoryConfig::PATH}")
      rescue Error
        NO_SEAM
      end
    end
  end
end
