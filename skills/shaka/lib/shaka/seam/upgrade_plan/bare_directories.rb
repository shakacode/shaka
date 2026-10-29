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

          shell_directory_dependency?(text, line_local: program_source?(text, path))
        end

        def shell_directory_dependency?(text, line_local: false)
          [text, normalize_shell_fragments(text)].any? do |source|
            source.match?(old_directory_change) || legacy_directory_command_pair?(source, line_local:)
          end
        end

        # In these languages a string only names a path; a change of directory is a call the check above already
        # finds. So a directory and a command on separate lines are two strings, not a command run inside it.
        def program_source?(text, path)
          path.to_s.match?(/\.(?:rb|py|js|cjs|mjs|ts)\z/) ||
            text.match?(%r{\A#!\S*(?:/|env\s+)(?:ruby|python3?|node)\b})
        end

        def directory_change?(text)
          [text, normalize_shell_fragments(text)].any? { |source| source.match?(old_directory_change) }
        end

        # env takes the directory as the -C argument itself, after any other options; a later path is the command
        # it runs.
        def old_directory_change = (@old_directory_change ||= directory_change_pattern(PATHS::DIRECTORY))

        def command_directory_change
          @command_directory_change ||= directory_change_pattern(PATHS::COMMAND_DIRECTORY)
        end

        def directory_change_pattern(directory)
          change = /(?:(?:cd|pushd)\s+|chdir\s*\()[^\n]*?|env\s+(?:[^\n]*?\s)?(?:-[A-Za-z]*C\s*|--chdir[=\s]\s*)\S*?/
          /(?<![\w-])(?:#{change})(?<![\w.-])#{Regexp.escape(directory)}(?![\w.-])/
        end

        def legacy_directory_command_pair?(text, line_local: false)
          bare = %r{(?<![\w.-])#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-]|/[[:alnum:]_-])}o
          names = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          # A bin/ inside a longer path, such as a full old or new command path, is not a command beside the directory.
          command = %r{(?<![\w./-])(?:\./)?bin[/'"\s,]+(?:#{names})\b}o
          sources = line_local ? text.each_line : [text]
          sources.any? { |source| source.match?(bare) && source.match?(command) }
        end
      end
    end
  end
end
