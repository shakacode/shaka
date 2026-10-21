# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Finds old paths assembled from shell quotes inside Markdown without joining prose apostrophes.
      module MarkdownFragments
        MARKDOWN_PATH = /\.(?:md|markdown|mdx)\z/i
        REMOVED_OR_KEPT = /(\\\r?\n|['"]|\\(?=[^\r\n]))|./m

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

        def old_token = /#{Regexp.escape(PATHS::DIRECTORY)}[^\s;|&()<>`]*/o

        def markdown_path?(path) = path.to_s.match?(MARKDOWN_PATH)
      end
    end
  end
end
