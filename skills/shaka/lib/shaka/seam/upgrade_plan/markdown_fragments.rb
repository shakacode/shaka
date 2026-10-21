# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Separates Markdown code from prose, so prose naming old paths, or holding apostrophes, does not
      # read as a shell dependency.
      module MarkdownFragments
        MARKDOWN_PATH = /\.(?:md|markdown|mdx)\z/i
        REMOVED_OR_KEPT = /(\\\r?\n|['"]|\\(?=[^\r\n]))|./m
        FENCE = /\A[ \t]*(`{3,}|~{3,})/
        # Quotes and list items can hold code, so their markers are removed before a line is classified.
        CONTAINER = /\A(?:[ \t]*(?:>|[-+*](?=[ \t])|\d{1,9}[.)](?=[ \t])))+[ \t]?/
        INDENTED = /\A(?: {4}|[ \t]*\t)/

        private

        # A prose apostrophe changes the joined text without touching a path, so Markdown blocks only
        # an old reference whose characters were split by a removed quote or escape.
        def markdown_fragmented_reference?(text, path)
          return false unless normalize_shell_fragments(text).include?(PATHS::DIRECTORY)

          joined, origins = joined_with_origins(text)
          joined.to_enum(:scan, old_token).any? { assembled_reference?(Regexp.last_match, origins, path) }
        end

        def assembled_reference?(match, origins, path)
          token = match[0]
          return false if origins[match.end(0) - 1] - origins[match.begin(0)] < token.length

          matching_paths(token).any? || directory_reference?(token, path)
        end

        def joined_with_origins(text)
          joined = +''
          origins = []
          text.to_enum(:scan, REMOVED_OR_KEPT).each do
            match = Regexp.last_match
            next if match[1]

            joined << match[0]
            origins << match.begin(0)
          end
          [joined, origins]
        end

        def markdown_document?(text, path)
          return false unless markdown_path?(path) && !text.start_with?('#!')

          !File.lstat(File.join(@root, path)).mode.anybits?(0o111)
        rescue SystemCallError
          false
        end

        # Markdown prose can name the old directory and a command paragraphs apart, so outside code the two
        # block only on one line, where agents may follow them as an instruction.
        def markdown_directory_dependency?(text)
          text.each_line.any? { |line| line.match?(old_directory_change) || legacy_directory_command_pair?(line) } ||
            shell_directory_dependency?(markdown_code(text))
        end

        # Markdown runs nothing outside code, so prose lines are blanked and fenced or indented lines stay.
        def markdown_code(text)
          code = markdown_code_lines(text)
          text.lines.each_with_index.map { |line, index| code[index] ? line : line.gsub(/[^\r\n]/, '') }.join
        end

        def markdown_prose_lines(text, path)
          return [] unless markdown_document?(text, path)

          markdown_code_lines(text).map(&:!)
        end

        def markdown_code_lines(text)
          fence = nil
          text.lines.map { |line| line.sub(CONTAINER, '') }.map do |line|
            if fence
              fence = nil if line.match?(/\A[ \t]*#{fence[0]}{#{fence.length},}[ \t]*$/)
              true
            else
              fence = line[FENCE, 1]
              !fence.nil? || line.match?(INDENTED)
            end
          end
        end

        # Prose names the old command directory as a place, so it is rewritten like a command path.
        def rewrite_prose_command_directory(line)
          pattern = %r{(?<![[:alnum:]_./-])(?<lead>\./)?#{Regexp.escape(PATHS::COMMAND_DIRECTORY)}
                       (?=/(?![[:alnum:]_-])|[^[:alnum:]_./-]|\.(?![[:alnum:]_/-])|$)}xo
          line.gsub(pattern) { "#{::Regexp.last_match[:lead]}#{PATHS::NEW_COMMAND_DIRECTORY}" }
        end

        def old_token = /#{Regexp.escape(PATHS::DIRECTORY)}[^\s;|&()<>`]*/o

        def markdown_path?(path) = path.to_s.match?(MARKDOWN_PATH)
      end
    end
  end
end
