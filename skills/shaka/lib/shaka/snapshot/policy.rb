# frozen_string_literal: true

require_relative '../error'
require_relative '../repository_config'

module Shaka
  class Snapshot
    # Answers whether this repository lets unfinished work leave the machine.
    #
    # The remote names its own default branch and supplies the seam from the exact commit it
    # reports for that branch, so nothing in the checkout chooses the answer or the place it
    # comes from. Everything is asked of the target the push would use, which may be a URL or
    # a path rather than a configured name. A remote that cannot be reached refuses, because
    # a push cannot be taken back. Only a remote advertising no refs at all keeps the
    # default, because it has published no contract to read.
    class Policy
      SYMREF = %r{\Aref:\s+refs/heads/(?<branch>\S+)\s+HEAD\b}

      def initialize(remote:, git:)
        @remote = remote
        @git = git
      end

      def allows_snapshot?
        return true if empty_remote?

        source = seam(default_branch)
        return true if source.nil?

        RepositoryConfig.recovery_from(source).fetch('snapshot')
      end

      private

      # Every ref counts here, not only heads: a remote holding just a tag has published
      # something, so it is not the brand-new repository that keeps the default.
      def empty_remote? = ask('ls-remote', @remote).strip.empty?

      # A remote holding branches must say which one is authoritative. An unadvertised or
      # dangling HEAD leaves the seam unread, which is not the same as having no contract.
      def default_branch
        branch_in(ask('ls-remote', '--symref', @remote, 'HEAD')) ||
          raise(Error, "Cannot read the default branch from #{@remote}; snapshots refuse.")
      end

      def ask(*argv)
        @git.call(*argv)
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
