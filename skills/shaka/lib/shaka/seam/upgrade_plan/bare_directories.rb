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

        # A quoted key in a hash or map names the directory as data, not a place to run from.
        def shell_directory_dependency?(text)
          text = text.gsub(/[{,]\s*\K(['"])#{Regexp.escape(PATHS::DIRECTORY)}\1(?=\s*(?:=>|:)\s)/o, '')
          [text, normalize_shell_fragments(text)].any? do |source|
            source.match?(old_directory_change) || legacy_directory_command_pair?(source)
          end
        end

        def directory_change?(text)
          [text, normalize_shell_fragments(text)].any? { |source| source.match?(old_directory_change) }
        end

        # env takes the directory as the -C argument itself, after any other options; a later path is the command
        # it runs.
        def old_directory_change
          change = /(?:(?:cd|pushd)\s+|chdir\s*\()[^\n]*?|env\s+(?:[^\n]*?\s)?(?:-[A-Za-z]*C\s*|--chdir[=\s]\s*)\S*?/
          /(?<![\w-])(?:#{change})(?<![\w.-])#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-])/o
        end

        def legacy_directory_command_pair?(text)
          bare = %r{(?<![\w.-])#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-]|/[[:alnum:]_-])}o
          return false unless text.match?(bare)

          names = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          # A bin/ inside a longer path, such as a full old or new command path, is not a command beside the directory.
          text.match?(%r{(?<![\w./-])(?:\./)?bin[/'"\s,]+(?:#{names})(?![\w-])}o)
        end
      end
    end
  end
end
