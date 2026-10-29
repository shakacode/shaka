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

          commands = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          code = without_recorded_commands(text)
          code.match?(%r{\bbin(?:/+(?:(?:\.{1,2}|bin)/+)*|['"\s,]+)(?:#{commands})(?![\w-])}o) ||
            code.match?(%r{['"]bin['"]\s*/\s*['"](?:#{commands})['"]}o)
        end

        # A comment, or a value in a hash or mapping, records a command line as data; it does not run it.
        def without_recorded_commands(text)
          text.gsub(%r{^\s*(?:#|//).*$}, '').gsub(%r{(?:=>\s*|^\s*[\w-]+:\s+)(['"]?)bin/[^\s'",]*\1}, '')
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
