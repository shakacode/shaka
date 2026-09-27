# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Recognizes exact command paths and broader references needing explicit repair.
      module ReferencePatterns
        private

        def command_directory_reference?(line)
          directory = Regexp.escape(PATHS::COMMAND_DIRECTORY)
          line.match?(Regexp.new("#{directory}(?:/(?![[:alnum:]_-])|(?=[^[:alnum:]_./-]|$))"))
        end

        def matching_paths(text)
          reference_mapping.keys.select do |old|
            text.match?(token_pattern(old)) || dynamic_reference?(text, old) || complex_reference?(text, old)
          end
        end

        def complex_reference?(text, old)
          escaped = Regexp.escape(old)
          prefix = '(?:\$\([^)]*\)/|(?:\.\./)+)'
          text.match?(Regexp.new("#{prefix}#{escaped}#{path_end}"))
        end

        def dynamic_reference?(text, old)
          escaped = Regexp.escape(old)
          variable = %r~(?:\$\{\{[^}]+\}\}|\$\{[^}]+\}|#\{[^}]+\})/#{escaped}#{path_end}~
          absolute = %r{(?:\A|[\s"'=])/(?:[^/\s"']+/)*#{escaped}#{path_end}}
          text.match?(variable) || text.match?(absolute)
        end

        def token_pattern(path)
          leading = '(?<![[:alnum:]_./-])(?<lead>\./|\$[A-Za-z_]\w*/|"\$[A-Za-z_]\w*"/)?'
          Regexp.new("#{leading}#{Regexp.escape(path)}#{path_end}")
        end

        def path_end = '(?!(?:[[:alnum:]_/-]|\\.[[:alnum:]_/-]))'

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
