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

      def summary(path) = "#{describe(path)}: #{path} loads and validates in this working tree"

      def describe(path)
        return 'team settings committed in this checkout' if git?('rev-parse', '--verify', '--quiet', "HEAD:./#{path}")
        return 'individual settings kept out of Git' if git?('check-ignore', '--quiet', '--', path)

        'settings not committed yet'
      end

      private

      # A Git that cannot run leaves the source unnamed rather than failing the settings check.
      def git?(*arguments)
        @runner.call(['git', *arguments], @root)[2]
      rescue SystemCallError
        false
      end
    end
  end
end
