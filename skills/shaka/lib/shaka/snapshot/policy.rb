# frozen_string_literal: true

require_relative '../error'
require_relative '../repository_config'
require_relative '../trusted_config_source'

module Shaka
  class Snapshot
    # Answers whether this repository lets unfinished work leave the machine.
    #
    # One listing from the target the push would use answers everything: whether it has
    # published anything at all, which branch it calls authoritative, and where that branch
    # points. Nothing in the checkout chooses the answer or the place it comes from, and the
    # target may be a URL or a path rather than a configured name. A remote that cannot be
    # reached refuses, because a push cannot be taken back. Only a remote advertising no
    # refs keeps the default, because it has published no contract to read.
    class Policy
      SYMREF = %r{\Aref:\s+refs/heads/(?<branch>\S+)\s+HEAD\b}

      def initialize(root:, remote:, git:)
        @root = root
        @remote = remote
        @git = git
      end

      def allows_snapshot?
        refs = listing
        return true if refs.strip.empty?

        source = seam(default_branch(refs), refs)
        return true if source.nil?

        RepositoryConfig.recovery_from(source).fetch('snapshot')
      end

      private

      def listing
        @git.call('ls-remote', '--symref', @remote)
      rescue Error
        raise Error, "Cannot reach #{@remote} to read its snapshot policy; snapshots refuse."
      end

      # A remote holding refs must say which branch is authoritative. An unadvertised or
      # dangling HEAD leaves the seam unread, which is not the same as having no contract.
      def default_branch(refs)
        match = refs.lines.lazy.filter_map { |line| SYMREF.match(line) }.first
        match&.[](:branch) ||
          raise(Error, "Cannot read the default branch from #{@remote}; snapshots refuse.")
      end

      # The seam is read from the commit the remote advertises for that branch, so a fetch
      # that fails leaves no earlier commit to answer in its place. Only a commit carrying no
      # seam says nothing, and `ls-tree` reports that as an empty listing rather than an error.
      def seam(branch, refs)
        head = tip(branch, refs)
        @git.call('fetch', '--quiet', @remote, "refs/heads/#{branch}")
        return nil if @git.call('ls-tree', head, '--', RepositoryConfig::PATH).strip.empty?

        TrustedConfigSource.new(root: @root).read(head)
      rescue Error
        raise Error, "Cannot read the trusted seam from #{@remote}; snapshots refuse."
      end

      def tip(branch, refs)
        line = refs.lines.find { |candidate| candidate.split("\t").last.to_s.strip == "refs/heads/#{branch}" }
        line&.split("\t")&.first ||
          raise(Error, "#{@remote} advertises no #{branch}.")
      end
    end
  end
end
