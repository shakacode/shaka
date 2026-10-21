# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Conservatively blocks old paths split across shell physical lines.
      module ContinuedReferences
        private

        def scan_complex_references(path, text)
          note_workflow_filters(path, text)
          scan_bare_directory_dependency(path, text)
          scan_segmented_reference(path, text)
          scan_continued_reference(path, text)
          scan_shell_fragmented_reference(path, text)
          scan_alias_reference(path, text)
          scan_unsupported_path_reference(path, text)
        end

        def scan_unsupported_path_reference(path, text)
          return unless unsupported_path_reference?(text)

          @references << { 'path' => path, 'kind' => 'unsupported old-path spelling', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: unsupported old-path spelling needs explicit repair"
        end

        def relative_helper_dependency?(path, text)
          return false unless path.start_with?("#{PATHS::DIRECTORY}/")
          return false if path.start_with?("#{PATHS::COMMAND_DIRECTORY}/")
          return false unless invocation_relative?(text)

          names = command_paths.map { |command| File.basename(command) }
          commands = names.map { |name| Regexp.escape(name) }.join('|')
          text.match?(%r{\bbin(?:/+(?:(?:\.{1,2}|bin)/+)*|['"\s,]+)(?:#{commands})\b}) ||
            text.match?(%r{['"]bin['"]\s*/\s*['"](?:#{commands})['"]})
        end

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

        def old_directory_change
          /(?<![\w-])(?:(?:cd|pushd)\s+|chdir\s*\()[^\n]*?#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-])/o
        end

        def legacy_directory_command_pair?(text)
          bare = %r{(?<![\w.-])#{Regexp.escape(PATHS::DIRECTORY)}(?![\w.-]|/[[:alnum:]_-])}o
          return false unless text.match?(bare)

          names = command_paths.map { |command| Regexp.escape(File.basename(command)) }.join('|')
          text.match?(%r{\bbin[/'"\s,]+(?:#{names})\b})
        end

        def scan_relative_helper_dependency(path, text)
          return unless relative_helper_dependency?(path, text)

          @references << { 'path' => path, 'kind' => 'relative old-command dependency',
                           'paths' => [PATHS::COMMAND_DIRECTORY] }
          @blockers << "#{path}: relative old-command dependency needs explicit repair"
        end

        def inspect_reference_file?(path, stat, absolute)
          return true if path.start_with?("#{PATHS::COMMAND_DIRECTORY}/")
          return false unless path.start_with?("#{PATHS::DIRECTORY}/")

          stat.mode.anybits?(0o111) || path.match?(/\.(?:sh|bash|rb|py)\z/) || File.binread(absolute, 2) == '#!'
        end

        def scan_segmented_reference(path, text)
          return unless segmented_reference?(text)

          @references << { 'path' => path, 'kind' => 'segmented old-layout reference', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: segmented old-layout reference needs explicit repair"
        end

        def scan_continued_reference(path, text)
          return unless continued_old_path?(text, path)

          @references << { 'path' => path, 'kind' => 'continued old-layout reference', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: continued old-layout reference needs explicit repair"
        end

        # Only the physical lines a continuation joins can hide a split path.
        def continued_old_path?(text, path = nil)
          text.scan(/^(?:[^\r\n]*\\\r?\n)+[^\r\n]*/).any? do |span|
            joined = span.gsub(/\\\r?\n/, '')
            matching_paths(joined).any? || directory_reference?(joined, path) || segmented_reference?(joined)
          end
        end

        def scan_alias_reference(path, text)
          return unless alias_reference?(text, path)

          @references << { 'path' => path, 'kind' => 'aliased old-layout directory', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: aliased old-layout directory needs explicit repair"
        end

        # Markdown is not executed, so a variable assigned the old directory there is not an alias.
        def alias_reference?(text, path = nil)
          return true if bare_directory_dependency?(text, path)
          return false if markdown_path?(path)

          assignment = /\b[A-Za-z_]\w*\s*[+?:]?=[^\r\n]*#{aliased_value}/o
          mapping = %r{\b[A-Za-z_]\w*\s*:[ \t]+[^\r\n]*#{Regexp.escape(PATHS::DIRECTORY)}/?(?=[ \t\r\n#'";]|$)}o
          [text, normalize_shell_fragments(text)].any? { |source| source.match?(assignment) || source.match?(mapping) }
        end

        # The new layout also lives under the old directory, so only the directory itself or a moved path aliases it.
        def aliased_value
          moved = [PATHS::CONTRACT, PATHS::REPOSITORY_ALLOWLIST].map { |old| Regexp.escape(old) }
          commands = "#{Regexp.escape(PATHS::COMMAND_DIRECTORY)}(?:/[[:alnum:]_.-]*)*"
          "(?:#{Regexp.escape(PATHS::DIRECTORY)}(?:/+\\.?)*|#{commands}|#{moved.join('|')})(?=[^[:alnum:]_./-]|$)"
        end

        def scan_shell_fragmented_reference(path, text)
          return unless shell_fragmented_reference?(text, path)

          @references << { 'path' => path, 'kind' => 'fragmented old-layout reference', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: fragmented old-layout reference needs explicit repair"
        end

        def shell_fragmented_reference?(text, path = nil)
          return markdown_fragmented_reference?(text, path) if markdown_document?(text, path)

          joined = normalize_shell_fragments(text)
          return false if joined == text

          matching_paths(joined).any? || directory_reference?(joined, path)
        end

        def normalize_shell_fragments(text)
          joined = text.gsub(/\\\r?\n/, '').delete(%q('"))
          joined.gsub(/\\(?=[^\r\n])/, '')
        end
      end
    end
  end
end
