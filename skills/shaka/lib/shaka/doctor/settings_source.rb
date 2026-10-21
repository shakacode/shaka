# frozen_string_literal: true

module Shaka
  class Doctor
    # Says whose settings the working tree holds, so a user can tell team setup from individual
    # setup. Committed settings are shared; individual setup keeps its files ignored by Git.
    class SettingsSource
      def initialize(root, runner)
        @root = root
        @runner = runner
      end

      def summary(path)
        loads = "#{path} loads and validates in this working tree"
        source = describe(path)
        source ? "#{source}: #{loads}" : loads
      end

      # Nil when Git cannot answer, such as outside a repository or through a symlinked path,
      # so the line names no source rather than guessing one.
      def describe(path)
        return 'team settings committed in this checkout' if committed?(path)

        output, _error, answered = git('status', '--porcelain', '--ignored', '--untracked-files=all', '--', path)
        return unless answered

        output.start_with?('!!') ? 'individual settings kept out of Git' : 'settings not committed yet'
      end

      private

      def committed?(path) = git('rev-parse', '--verify', '--quiet', "HEAD:./#{path}")[2]

      def git(*arguments)
        @runner.call(['git', *arguments], @root)
      rescue SystemCallError
        ['', '', false]
      end
    end
  end
end
