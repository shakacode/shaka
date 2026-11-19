# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative '../trusted_path_resolver'
require_relative 'git_memo'
require_relative 'paths'
require_relative 'private_git_paths'

module Shaka
  module Configuration
    # Names the contract and its complete command directory, and checks they are real files.
    class Layout
      attr_reader :contract, :command_directory, :required, :optional

      def initialize(contract:, command_directory:, required:, optional:)
        @contract = contract
        @command_directory = command_directory
        @required = required
        @optional = optional
      end

      def commands = required.merge(optional)

      CURRENT = new(contract: Paths::CONTRACT, command_directory: Paths::COMMAND_DIRECTORY,
                    required: Paths::REQUIRED_COMMANDS, optional: Paths::OPTIONAL_COMMANDS).freeze

      def self.worktree(root:, allow_missing: false)
        validate_root_directory!(root)
        chosen = select(entry?(File.join(root, CURRENT.contract)), allow_missing:)
        validate_worktree!(root, chosen) if chosen
        chosen
      end

      def self.validate_root_directory!(root)
        directory = File.join(root, Paths::DIRECTORY)
        raise Error, "#{Paths::DIRECTORY} must be a real directory, not a symlink" if File.symlink?(directory)
        return unless File.exist?(directory)
        return if File.directory?(directory)

        raise Error, "#{Paths::CONTRACT} cannot be read: #{Paths::DIRECTORY} is not a real directory"
      end

      def self.validate_worktree!(root, chosen)
        directories = [Paths::DIRECTORY, File.dirname(chosen.contract)].uniq
        directories.each do |relative|
          path = File.join(root, relative)
          raise Error, "#{relative} must be a real directory, not a symlink" if File.symlink?(path)
        end

        return if File.file?(File.join(root, chosen.contract)) && !File.symlink?(File.join(root, chosen.contract))

        raise Error, "#{chosen.contract} must be a regular file"
      end

      DEFAULT_GIT = ->(*arguments) { Open3.capture3('git', *arguments) }
      # A runner with a timeout can report a present file as missing, so only these answers are remembered.
      UNBOUNDED_GIT = [DEFAULT_GIT, PrivateGitPaths.method(:command)].freeze

      def self.commit(root:, sha:, allow_missing: false, git: nil)
        git ||= DEFAULT_GIT
        return commit_layout(root, sha, allow_missing, git) unless UNBOUNDED_GIT.include?(git)

        # The key names the runner, because the private source runs Git without inherited Git variables.
        # A missing contract is kept only once the commit itself is local, so a commit fetched later is read again.
        keep = ->(chosen) { chosen || local_commit?(root, sha, git) }
        GitMemo.commit([:layout, git, root, sha, allow_missing], sha, keep:) do
          commit_layout(root, sha, allow_missing, git)
        end
      end

      def self.local_commit?(root, sha, git)
        GitMemo.capture([:commit_object, git, root, sha], sha) do
          git.call('-C', root, 'cat-file', '-e', "#{sha}^{commit}")
        end.last.success?
      end

      def self.commit_layout(root, sha, allow_missing, git)
        _out, _error, status = git.call('-C', root, 'cat-file', '-e', "#{sha}:#{CURRENT.contract}")
        chosen = select(status.success?, allow_missing:)
        validate_commit!(root, sha, chosen, git) if chosen
        chosen
      end

      private_class_method :local_commit?, :commit_layout

      def self.validate_commit!(root, sha, chosen, git)
        entry = TrustedPathResolver.new(root:, sha:, git:).entry(chosen.contract)
        return if entry && entry.last == 'blob' && entry.first != TrustedPathResolver::SYMLINK.first

        raise Error, "#{chosen.contract} at #{sha} must be a regular file"
      end

      def self.select(present, allow_missing:)
        return CURRENT if present
        return if allow_missing

        raise Error, "Cannot find #{CURRENT.contract}"
      end

      def self.entry?(path)
        File.lstat(path)
        true
      rescue Errno::ENOENT, Errno::ENOTDIR
        false
      end
    end
  end
end
