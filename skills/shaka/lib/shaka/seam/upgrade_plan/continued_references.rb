# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Conservatively blocks old paths split across shell physical lines.
      module ContinuedReferences
        include BareDirectories
        include HelperCommands

        private

        def scan_complex_references(path, text)
          note_glob_contexts(path, text)
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
          text = resolved_joins(without_machine_paths(text))
          [text, normalize_shell_fragments(text)].any? do |source|
            source.match?(assignment) || source.match?(mapping) || source.match?(composed_assignment)
          end
        end

        # A command-directory prefix with more appended may spell a moved command, such as the prefix plus `val`
        # joined to `idate`.
        def composed_assignment
          %r{\b[A-Za-z_]\w*\s*[+?:]?=[^\r\n]*#{Regexp.escape(PATHS::COMMAND_DIRECTORY)}/[[:alnum:]_.-]*['"]?\s*(?:\+|<<)}o
        end

        # The new layout also lives under the old directory, so only the directory itself or a moved path aliases it.
        # The repository's own tools stay in the command directory, so naming one of them is not an alias. A regex
        # or glob alternation lists the directory as a pattern to match, not a place to run from.
        def aliased_value
          moved = [PATHS::CONTRACT, PATHS::REPOSITORY_ALLOWLIST, *command_paths].map { |old| Regexp.escape(old) }
          directories = "#{Regexp.escape(PATHS::DIRECTORY)}(?:/+\\.?)*|#{Regexp.escape(PATHS::COMMAND_DIRECTORY)}/*"
          "(?<![\\\\|])(?:#{directories}|#{moved.join('|')})(?=[^[:alnum:]_./|-]|$)"
        end

        def scan_shell_fragmented_reference(path, text)
          return unless shell_fragmented_reference?(text, path)

          @references << { 'path' => path, 'kind' => 'fragmented old-layout reference', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: fragmented old-layout reference needs explicit repair"
        end

        def shell_fragmented_reference?(text, path = nil)
          return markdown_fragmented_reference?(text, path) if markdown_document?(text, path)

          text.gsub(/\\\r?\n/, '').each_line.any? { |line| fragment_joins_reference?(line, path) }
        end

        # Quotes and escapes around a whole path hide nothing; only a reference they split counts.
        def fragment_joins_reference?(line, path)
          joined = normalize_shell_fragments(line)
          return false if joined == line || !layout_reference?(joined, path)

          !layout_reference?(line, path) ||
            [PATHS::DIRECTORY, *reference_mapping.keys].any? { |old| joined.scan(old).size > line.scan(old).size }
        end

        def layout_reference?(text, path) = matching_paths(text).any? || directory_reference?(text, path)

        def normalize_shell_fragments(text)
          joined = text.gsub(/\\\r?\n/, '').delete(%q('"))
          joined.gsub(/\\(?=[^\r\n])/, '')
        end
      end
    end
  end
end
