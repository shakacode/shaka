# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'refusal'

module Shaka
  module Install
    # Inspects incoming revisions without exposing them through the installation links.
    module CheckoutGit
      AUTHENTICATION_ENV = %w[GIT_SSH GIT_SSH_COMMAND GIT_SSH_VARIANT GIT_ASKPASS GIT_TERMINAL_PROMPT
                              GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM].freeze

      # stage writes its worktree's path here before creating it, so a killed update leaves proof of what it
      # made. Only that path is removed; a worktree no record names is a person's, whatever its path.
      STAGING_RECORD = 'shaka-update-staging'
      STAGING_PATH = %r{/shaka-update\d{8}-\d+-[a-z0-9]+/source\z}

      def revision = git('rev-parse', 'HEAD')

      # A killed update skips stage's cleanup. The caller holds the checkout lock, so no update is using it.
      def clear_staging
        path = staging_path
        return unless path

        remove_staging(path)
        Dir.rmdir(File.dirname(path))
      rescue SystemCallError
        nil
      end

      private

      # The recorded path, or nil when no update is staging. A record naming another kind of path is ignored.
      def staging_path
        path = File.read(staging_record).strip
        path if path.match?(STAGING_PATH)
      rescue SystemCallError
        nil
      end

      def staging_record = File.join(@root, '.git', STAGING_RECORD)

      # The second --force removes a worktree Git still marks locked because the kill came during worktree add.
      def remove_staging(path)
        registered = git('worktree', 'list', '--porcelain').lines.map(&:chomp).include?("worktree #{path}")
        git('worktree', 'remove', '--force', '--force', path) if registered
        FileUtils.rm_f(staging_record)
      end

      def advance(candidate)
        git('merge', '--quiet', '--ff-only', candidate)
      rescue ArgumentError
        write_record(@record.except('pending_revision')) if revision == @record['revision']
        raise
      end

      def stage(candidate)
        Dir.mktmpdir('shaka-update') do |directory|
          path = File.join(File.realpath(directory), 'source')
          File.write(staging_record, "#{path}\n", perm: 0o600)
          begin
            git('worktree', 'add', '--quiet', '--detach', path, candidate)
            yield path
          ensure
            remove_staging(path)
          end
        end
      end

      # Clone and fetch fail alike when origin lacks the branch and when Git cannot reach origin. ls-remote's
      # exit status tells them apart, because Git's wording changes with version and locale. When origin has the
      # branch, the failure is neither, so Git's own message stands.
      def reaching(remote)
        yield
      rescue ArgumentError => e
        raise ArgumentError, remote_refusal(remote) || e.message
      end

      # The printed check runs where the probe ran, so a relative repository path names the same repository,
      # and -- keeps a repository that starts with a hyphen from being read as an option.
      def remote_refusal(remote)
        _, _, status = run_git('ls-remote', '--exit-code', '--heads', '--', remote, "refs/heads/#{@branch}")
        return if status.success?

        list = Refusal.command('git', '-C', @root, 'ls-remote', '--heads', '--', Refusal.url(remote))
        return missing_branch(list) if status.exitstatus == 2

        Refusal.message('Installation could not download Shaka', "Git could not reach #{Refusal.url(@repository)}",
                        "run #{list} to check the network and access, then run this command again")
      end

      def missing_branch(list)
        shown = Refusal.url(@repository)
        Refusal.message("Installation branch #{@branch} is not on #{shown}", "#{shown} has no branch #{@branch}",
                        Refusal.decide('which branch to install', 'to list its branches', list))
      end

      def git(*)
        output, error, status = run_git(*)
        raise ArgumentError, "Installation Git operation failed: #{error.strip}" unless status.success?

        output.strip
      end

      # For a caller that reads Git's answer from its exit status.
      def run_git(*arguments)
        preserved = %w[clone fetch ls-remote].include?(arguments.first) ? AUTHENTICATION_ENV : []
        environment = (ENV.keys.grep(/\AGIT_/) - preserved).to_h { |key| [key, nil] }
        Open3.capture3(environment, 'git', '-c', "core.hooksPath=#{File::NULL}",
                       '-c', 'submodule.recurse=false', '-C', @root, *arguments, umask: 0o022)
      end
    end
  end
end
