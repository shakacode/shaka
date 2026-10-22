# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Blocks a change into the old layout directory, or the directory named beside a moved command.
      module BareDirectories
        private

        def scan_bare_directory_dependency(path, text)
          return unless bare_directory_dependency?(text, path)

          @references << { 'path' => path, 'kind' => 'bare old-layout directory', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: bare old-layout directory needs explicit repair"
        end

        def bare_directory_dependency?(text, path = nil)
          return markdown_directory_dependency?(text) if markdown_document?(text, path)

          shell_directory_dependency?(text)
        end

        def shell_directory_dependency?(text)
          [text, normalize_shell_fragments(text)].any? do |source|
            source.match?(old_directory_change) || legacy_directory_command_pair?(source)
          end
        end

        # Prose blocks a change into the old directory, or a moved command it says to run from there.
        def prose_directory_dependency?(text)
          [text, normalize_shell_fragments(text)].any? { |source| source.match?(old_directory_change) } ||
            prose_command_from_directory?(text.delete('`').gsub(/\s+/, ' '))
        end

        # env takes the directory as the -C argument itself; a later path is the command it runs.
        def old_directory_change
          change = /(?:(?:cd|pushd)\s+|chdir\s*\()[^\n]*?|env\s+(?:-C\s*|--chdir[=\s]\s*)\S*?/
          /(?<![\w-])(?:#{change})#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-])/o
        end

        def prose_command_from_directory?(text)
          # A sentence may end right after the directory, so a closing period still leaves it bare.
          directory = %r{(?<![\w.-])#{Regexp.escape(PATHS::DIRECTORY)}/?(?![\w-]|\.\w|/[[:alnum:]_-])}o
          place = /(?i:from|in|inside|within|under)\s+(?:the\s+)?['"]?#{directory}['"]?/
          command = /(?<![\w.-])#{command_name}/
          text.match?(/#{command}['"]?,?\s+#{place}/) ||
            text.match?(/#{place}(?:\s+directory)?,?\s+(?:run\s+)?['"]?#{command}/)
        end

        def legacy_directory_command_pair?(text)
          return false unless text.match?(bare_directory)

          # A full old command path is rewritten whole, so its bin/ part is not a command beside the directory.
          text.match?(%r{(?<!#{Regexp.escape(PATHS::DIRECTORY)}/)\b#{command_name}})
        end

        def bare_directory = %r{(?<![\w.-])#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-]|/[[:alnum:]_-])}o

        def command_name
          names = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          %r{bin[/'"\s,]+(?:#{names})\b}
        end
      end
    end
  end
end
