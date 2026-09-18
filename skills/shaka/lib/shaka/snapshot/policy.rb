# frozen_string_literal: true

require_relative '../error'
require_relative '../repository_config'

module Shaka
  class Snapshot
    # Answers whether this repository lets unfinished work leave the machine.
    #
    # The remote names its own default branch and supplies the seam from it, so nothing in
    # the checkout chooses the answer or the place it comes from. A remote that cannot be
    # reached refuses, because a push cannot be taken back. A remote whose default branch
    # carries no seam has said nothing, and a repository with no remote has nowhere to
    # publish, so both keep the default.
    class Policy
      SYMREF = %r{\Aref:\s+refs/heads/(?<branch>\S+)\s+HEAD\b}

      def initialize(root:, remote:, git:)
        @root = root
        @remote = remote
        @git = git
      end

      def allows_snapshot?
        return true unless remote?

        listing = symrefs
        return true if listing.strip.empty?

        branch = branch_in(listing)
        raise Error, "Cannot read the default branch from #{@remote}; snapshots refuse." if branch.nil?

        source = seam(branch)
        return true if source.nil?

        RepositoryConfig.new(root: @root, source: source).load.recovery.fetch('snapshot')
      end

      private

      def remote? = !@git.call('remote').split("\n").empty?

      # An empty listing means a remote with no branches; a failure means no answer at all.
      def symrefs
        @git.call('ls-remote', '--symref', @remote, 'HEAD')
      rescue Error
        raise Error, "Cannot reach #{@remote} to read its snapshot policy; snapshots refuse."
      end

      def branch_in(listing)
        match = listing.lines.lazy.filter_map { |line| SYMREF.match(line) }.first
        match && match[:branch]
      end

      # The seam is read from the fetched remote commit, never from the working tree.
      def seam(branch)
        @git.call('fetch', '--quiet', @remote, "refs/heads/#{branch}")
        @git.call('show', "FETCH_HEAD:#{RepositoryConfig::PATH}")
      rescue Error
        fetched?(branch) ? nil : raise(Error, "Cannot read the trusted seam from #{@remote}.")
      end

      def fetched?(branch)
        @git.call('rev-parse', '--verify', '--end-of-options', 'FETCH_HEAD^{commit}')
        @git.call('ls-remote', @remote, "refs/heads/#{branch}")
        true
      rescue Error
        false
      end
    end
  end
end
