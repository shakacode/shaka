# frozen_string_literal: true

require_relative '../error'
require_relative '../repository_config'

module Shaka
  class Snapshot
    # Answers whether this repository lets unfinished work leave the machine.
    #
    # The remote names its own default branch and supplies the seam from the exact commit it
    # reports for that branch, so nothing in the checkout chooses the answer or the place it
    # comes from. A remote that cannot be reached refuses, because a push cannot be taken
    # back. A remote with no branches has published no contract, and a repository with no
    # remote has nowhere to publish, so both keep the default.
    class Policy
      SYMREF = %r{\Aref:\s+refs/heads/(?<branch>\S+)\s+HEAD\b}

      def initialize(remote:, git:)
        @remote = remote
        @git = git
      end

      def allows_snapshot?
        return true unless remote?

        branch = default_branch
        return true if branch.nil?

        source = seam(branch)
        return true if source.nil?

        RepositoryConfig.recovery_from(source).fetch('snapshot')
      end

      private

      def remote? = !@git.call('remote').split("\n").empty?

      def default_branch
        listing = symrefs
        return nil if listing.strip.empty?

        branch_in(listing) ||
          raise(Error, "Cannot read the default branch from #{@remote}; snapshots refuse.")
      end

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

      # The seam is read from the commit the remote reports, so a fetch that fails leaves no
      # earlier commit to answer in its place. Only a commit that carries no seam says
      # nothing, and `ls-tree` reports that as an empty listing rather than a failure.
      def seam(branch)
        head = remote_head(branch)
        @git.call('fetch', '--quiet', @remote, "refs/heads/#{branch}")
        return nil if @git.call('ls-tree', head, '--', RepositoryConfig::PATH).strip.empty?

        @git.call('show', "#{head}:#{RepositoryConfig::PATH}")
      rescue Error
        raise Error, "Cannot read the trusted seam from #{@remote}; snapshots refuse."
      end

      def remote_head(branch)
        head = @git.call('ls-remote', @remote, "refs/heads/#{branch}").split(/\s/).first.to_s
        raise Error, "#{@remote} has no #{branch}." if head.empty?

        head
      end
    end
  end
end
