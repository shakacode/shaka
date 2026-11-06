# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module Shaka
  module Install
    # Inspects incoming revisions without exposing them through the installation links.
    module CheckoutGit
      AUTHENTICATION_ENV = %w[GIT_SSH GIT_SSH_COMMAND GIT_SSH_VARIANT GIT_ASKPASS GIT_TERMINAL_PROMPT
                              GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM].freeze

      # stage checks the candidate out detached in the source folder of a Dir.mktmpdir('shaka-update') folder.
      # A worktree list entry that matches both is the installer's own; any other worktree is a person's.
      STAGING_PATH = %r{/shaka-update\d{8}-\d+-[a-z0-9]+/source\z}

      def self.staging?(entry) = entry.match?(/^detached$/) && entry[/^worktree (.+)$/, 1].to_s.match?(STAGING_PATH)

      def revision = git('rev-parse', 'HEAD')

      # A killed update skips stage's cleanup. The caller holds the checkout lock, so no update is using these.
      def clear_staging
        staging_worktrees.each { |path| git('worktree', 'remove', '--force', path) }
      end

      private

      # Listed whether or not the folder still exists, since either way Git keeps the entry.
      def staging_worktrees
        entries = git('worktree', 'list', '--porcelain').split(/\n\n+/).drop(1)
        entries.select { |entry| CheckoutGit.staging?(entry) }.map { |entry| entry[/^worktree (.+)$/, 1] }
      end

      def advance(candidate)
        git('merge', '--quiet', '--ff-only', candidate)
      rescue ArgumentError
        write_record(@record.except('pending_revision')) if revision == @record['revision']
        raise
      end

      def stage(candidate)
        Dir.mktmpdir('shaka-update') do |directory|
          path = File.join(directory, 'source')
          git('worktree', 'add', '--quiet', '--detach', path, candidate)
          begin
            yield File.realpath(path)
          ensure
            git('worktree', 'remove', '--force', path)
          end
        end
      end

      def git(*arguments)
        preserved = %w[clone fetch ls-remote].include?(arguments.first) ? AUTHENTICATION_ENV : []
        environment = (ENV.keys.grep(/\AGIT_/) - preserved).to_h { |key| [key, nil] }
        output, error, status = Open3.capture3(environment, 'git', '-c', "core.hooksPath=#{File::NULL}",
                                               '-c', 'submodule.recurse=false', '-C', @root, *arguments, umask: 0o022)
        raise ArgumentError, "Installation Git operation failed: #{error.strip}" unless status.success?

        output.strip
      end
    end
  end
end
