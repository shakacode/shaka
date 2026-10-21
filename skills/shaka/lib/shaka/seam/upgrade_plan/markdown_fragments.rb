# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Finds old paths assembled from shell quotes inside Markdown without joining prose apostrophes.
      module MarkdownFragments
        MARKDOWN_PATH = /\.(?:md|markdown|mdx)\z/i

        private

        # Prose apostrophes would join a whole document, so Markdown joins each word on its own
        # and blocks only an old reference that joining reveals.
        def markdown_fragmented_reference?(text, path)
          text.split.any? do |word|
            joined = normalize_shell_fragments(word)
            next false if joined == word

            (matching_paths(joined) - matching_paths(word)).any? ||
              (directory_reference?(joined, path) && !directory_reference?(word, path))
          end
        end

        def markdown_document?(text, path)
          return false unless markdown_path?(path) && !text.start_with?('#!')

          !File.lstat(File.join(@root, path)).mode.anybits?(0o111)
        rescue SystemCallError
          false
        end

        def markdown_path?(path) = path.to_s.match?(MARKDOWN_PATH)
      end
    end
  end
end
