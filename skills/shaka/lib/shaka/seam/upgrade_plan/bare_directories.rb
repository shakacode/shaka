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

        def directory_change?(text)
          [text, normalize_shell_fragments(text)].any? { |source| source.match?(old_directory_change) }
        end

        def old_directory_change
          /(?<![\w-])(?:(?:cd|pushd|env\s+-C)\s+|chdir\s*\()[^\n]*?#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-])/o
        end

        def legacy_directory_command_pair?(text)
          bare = %r{(?<![\w.-])#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-]|/[[:alnum:]_-])}o
          return false unless text.match?(bare)

          names = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          # A full old command path is rewritten whole, so its bin/ part is not a command beside the directory.
          text.match?(%r{(?<!#{Regexp.escape(PATHS::DIRECTORY)}/)\bbin[/'"\s,]+(?:#{names})\b})
        end
      end
    end
  end
end
