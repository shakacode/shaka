# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Separates Markdown code from prose, so prose naming old paths, or holding apostrophes, does not
      # read as a shell dependency.
      module MarkdownFragments
        MARKDOWN_PATH = /\.(?:md|markdown|mdx)\z/i
        REMOVED_OR_KEPT = /(\\\r?\n|['"]|\\(?=[^\r\n]))|./m

        # Follows which Markdown lines are fenced or indented code. Doubtful lines count as code, so an
        # indented line continuing a prose paragraph is code too.
        class CodeLines
          # A fence starts at most three spaces in, and a backtick fence's info text holds no backtick.
          FENCE = /\A {0,3}(`{3,}(?=[^`]*\z)|~{3,})/
          # Quotes and list items can hold code, so their markers are removed before a line is classified.
          CONTAINER = /\A(?:[ \t]*(?:>|[-+*](?=[ \t])|\d{1,9}[.)](?=[ \t])))+[ \t]?/
          INDENTED = /\A(?: {4}|[ \t]*\t)/

          def initialize
            @fence = nil
            @prefix = ''
          end

          def code?(raw)
            line = raw.sub(CONTAINER, '')
            return inside_fence?(raw) if @fence
            return true if raw.match?(INDENTED) || line.match?(INDENTED)

            @fence = line[FENCE, 1]
            @prefix = marker_columns(raw[0, raw.length - line.length])
            !@fence.nil?
          end

          private

          # A fence closes only behind its opener's own quote markers, so a quoted fence line inside it stays
          # content. List markers count as the spaces that continue their item.
          def inside_fence?(raw)
            rest = raw[@prefix.length..].to_s
            closes = marker_columns(raw[0, @prefix.length]) == @prefix &&
                     rest.match?(/\A {0,3}#{@fence[0]}{#{@fence.length},}[ \t]*\r?$/)
            @fence = nil if closes
            true
          end

          def marker_columns(prefix) = prefix.gsub(/[-+*]|\d{1,9}[.)]/) { |marker| ' ' * marker.length }
        end

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
        # block only within one paragraph, where agents may follow them as an instruction.
        def markdown_directory_dependency?(text)
          text.split(/\n(?:[ \t]*\r?\n)+/).any? { |paragraph| shell_directory_dependency?(paragraph) } ||
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
          code = CodeLines.new
          text.lines.map { |line| code.code?(line) }
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
