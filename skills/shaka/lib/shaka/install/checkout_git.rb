# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module Shaka
  module Install
    # Inspects incoming revisions without exposing them through the installation links.
    module CheckoutGit
      private

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

      def git(*)
        environment = ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] }
        output, error, status = Open3.capture3(environment, 'git', '-c', "core.hooksPath=#{File::NULL}",
                                               '-c', 'submodule.recurse=false', '-C', @root, *, umask: 0o022)
        raise ArgumentError, "Installation Git operation failed: #{error.strip}" unless status.success?

        output.strip
      end
    end
  end
end
