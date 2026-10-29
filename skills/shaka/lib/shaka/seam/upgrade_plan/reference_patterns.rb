# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Recognizes exact command paths and broader references needing explicit repair.
      module ReferencePatterns
        include WholeDirectoryGlobs
        include LiteralPaths

        private

        def command_directory_reference?(line)
          line.match?(directory_pattern(PATHS::COMMAND_DIRECTORY, "(?:/(?![[:alnum:]_-])|#{directory_end})"))
        end

        def layout_glob_reference?(line, path = nil)
          without_whole_directory_globs(line, path).match?(directory_pattern(PATHS::DIRECTORY, '/(?:\\*|\\?)'))
        end

        def directory_pattern(path, ending)
          directory = Regexp.escape(path)
          bare = "(?<![[:alnum:]_./-])(?:\\./)?#{directory}"
          variable_prefix = '(?:\\$[A-Za-z_]\\w*|"\\$[A-Za-z_]\\w*"|\\$\\{\\{[^}]+\\}\\}|' \
                            '\\$\\{[^}]+\\}|#\\{[^}]+\\}|\\$\\([^)]*\\))'
          variable = "#{variable_prefix}/+(?:\\./|\\.\\./)*#{directory}"
          parent = "(?<![[:alnum:]_./-])(?:\\.\\./)+#{directory}"
          absolute = "(?<![[:alnum:]_./-])/(?:[^/\\s\"']+/)*#{directory}"
          url = "https?://[^\\s\"'<>]*/#{directory}"
          Regexp.new("(?:#{bare}|#{variable}|#{parent}|#{absolute}|#{url})#{ending}")
        end

        def directory_reference?(line, path = nil)
          moved_command_directory_reference?(line, path) || layout_glob_reference?(line, path) ||
            normalized_internal_reference?(line)
        end

        def moved_command_directory_reference?(line, path = nil)
          command_directory_reference?(line) && !retained_command_directory?(line, path)
        end

        def normalized_internal_reference?(line)
          return true if parent_traversal_reference?(line)
          return false unless line.include?("#{PATHS::DIRECTORY}/./") || line.include?("#{PATHS::DIRECTORY}//")

          [PATHS::COMMAND_DIRECTORY, PATHS::CONTRACT, PATHS::REPOSITORY_ALLOWLIST].any? do |old|
            suffix = Regexp.escape(old.delete_prefix("#{PATHS::DIRECTORY}/"))
            line.match?(directory_pattern(PATHS::DIRECTORY, "/(?:\\./|/)+#{suffix}(?:/|#{directory_end})"))
          end
        end

        # Every start is tried, and every `../` in a match, so a link after a traversal cannot hide it.
        def parent_traversal_reference?(line)
          return false unless line.include?("#{PATHS::DIRECTORY}/") && line.include?('/../')

          pattern = directory_pattern(PATHS::DIRECTORY, '/(?<segments>(?:[^/\s"\x27]+/)*)\.\./')
          line.to_enum(:scan, /(?=#{pattern})/).any? { checkout_traversal?(::Regexp.last_match[:segments]) }
        end

        # Markdown puts `](` between a link's text and its target, so a segment holding it is a
        # directory only where the checkout has one.
        def checkout_traversal?(segments)
          directory = File.join(@root, PATHS::DIRECTORY)
          "#{segments}..".split('/').each do |segment|
            return true if segment == '..'

            directory = File.join(directory, segment)
            return false if segment.include?('](') && !File.directory?(directory)
          end
        end

        def directory_end = '(?=[^[:alnum:]_./-]|\\.(?![[:alnum:]_/-])|$)'

        def matching_paths(text)
          text = without_machine_paths(text)
          reference_mapping.keys.select do |old|
            text.match?(token_pattern(old)) || dynamic_reference?(text, old) || complex_reference?(text, old)
          end
        end

        def unsupported_path_reference?(text)
          paths = reference_mapping.keys + [PATHS::COMMAND_DIRECTORY]
          paths.any? do |old|
            (text.include?("#{old}.") && text.match?(Regexp.new("#{Regexp.escape(old)}\\.[[:alnum:]_]"))) ||
              text.include?(old.tr('/', '\\'))
          end
        end

        def complex_reference?(text, old)
          escaped = Regexp.escape(old)
          prefix = '(?:\$\([^)]*\)/|(?:\.\./)+)'
          text.match?(Regexp.new("#{prefix}#{escaped}#{path_end}"))
        end

        def dynamic_reference?(text, old)
          escaped = Regexp.escape(old)
          prefix = '(?:\$[A-Za-z_]\w*|"\$[A-Za-z_]\w*"|\$\{\{[^}]+\}\}|\$\{[^}]+\}|#\{[^}]+\})'
          variable = Regexp.new("#{prefix}/+(?:\\./|\\.\\./)*#{escaped}#{path_end}")
          absolute = %r{(?<![[:alnum:]_./-])/(?:[^/\s"']+/)*#{escaped}#{path_end}}
          url = %r{\bhttps?://[^\s"'<>]*/#{escaped}#{path_end}}
          text.match?(variable) || text.match?(absolute) || text.match?(url)
        end

        def token_pattern(path)
          leading = '(?<![[:alnum:]_./-])(?<lead>\./)?'
          Regexp.new("#{leading}#{Regexp.escape(path)}#{path_end}")
        end

        def path_end = '(?!(?:[[:alnum:]_/-]|\\.[[:alnum:]_/-]))'

        def historical_line?(path, line)
          return true if File.basename(path).match?(/\A(?:CHANGELOG|HISTORY|RELEASE[-_]?NOTES)(?:\.|\z)/i)

          path.end_with?('.md') &&
            line.match?(/\A\s*(?:[-*]\s*)?(?:previously|formerly|historically|before upgrade|old path)\b/i)
        end

        def reference_mapping
          { PATHS::CONTRACT => PATHS::NEW_CONTRACT,
            PATHS::REPOSITORY_ALLOWLIST => PATHS::NEW_REPOSITORY_ALLOWLIST }.merge(
              command_paths.to_h { |old| [old, old.sub(PATHS::COMMAND_DIRECTORY, PATHS::NEW_COMMAND_DIRECTORY)] }
            )
        end
      end
    end
  end
end
