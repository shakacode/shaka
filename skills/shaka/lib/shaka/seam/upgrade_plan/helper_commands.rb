# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Files inside the old layout that reach a moved command relative to their own location.
      module HelperCommands
        private

        def relative_helper_dependency?(path, text)
          return false unless path.start_with?("#{PATHS::DIRECTORY}/")
          return false if path.start_with?("#{PATHS::COMMAND_DIRECTORY}/")
          return false unless invocation_relative?(text)

          joined_command_path?(text) || own_directory_command?(text)
        end

        # A file that changes into its own directory runs a bare bin/<command> from there.
        def own_directory_command?(text)
          own = /(?:\bcd|\bpushd)\s+["']?\$\(\s*dirname\s|
                 chdir\(\s*(?:__dir__|__dirname|File\.dirname|os\.path\.dirname)/x
          commands = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          text.match?(own) && text.match?(%r{(?<![\w./-])(?:\./)?bin/+(?:#{commands})\b}o)
        end

        # A bare bin/<command> runs from the working directory, which is the repository's own bin/; only a path
        # joined onto something, or resolved against the file's own directory, can reach the old command directory.
        def joined_command_path?(text)
          commands = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          resolved = %r{(['"])bin/+(?:#{commands})\1}o
          statements(text).any? { |line| line.match?(resolved) && invocation_relative?(line) } ||
            text.match?(%r{\S/+bin/+(?:(?:\.{1,2}|bin)/+)*(?:#{commands})\b}o) ||
            text.match?(/,\s*(['"])bin\1\s*,\s*(['"])(?:#{commands})\2/o) ||
            text.match?(%r{['"]bin['"]\s*/\s*['"](?:#{commands})['"]}o)
        end

        def scan_relative_helper_dependency(path, text)
          return unless relative_helper_dependency?(path, text)

          @references << { 'path' => path, 'kind' => 'relative old-command dependency',
                           'paths' => [PATHS::COMMAND_DIRECTORY] }
          @blockers << "#{path}: relative old-command dependency needs explicit repair"
        end
      end
    end
  end
end
