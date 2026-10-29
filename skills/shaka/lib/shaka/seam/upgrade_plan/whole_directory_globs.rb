# frozen_string_literal: true

require 'yaml'

module Shaka
  class Seam
    class UpgradePlan
      # Removes old-directory `**` globs that still cover every moved path: event path filters in a GitHub
      # Actions workflow, or lines of an ignore or CODEOWNERS file.
      module WholeDirectoryGlobs
        private

        def without_whole_directory_globs(line, path)
          if filtered_workflows.include?(path)
            line.gsub(terminal_glob, '')
          elsif ignore_or_owners_file?(path)
            line.gsub(ignore_glob_entry, '\k<prefix>')
          else
            without_inert_globs(line, path)
          end
        end

        # A comment runs nothing, and a shell `case` pattern's `*` also matches `/`, so a whole-directory glob there
        # still covers every moved path.
        def without_inert_globs(line, path)
          return '' if !markdown_path?(path) && line.match?(%r[\A\s*(?:#(?![!{])|//)])
          return line unless shell_scripts.include?(path) && line.match?(case_arm)

          line.gsub(case_arm_glob, '')
        end

        def case_arm = /\A\s*\(?[^\s()|]+(?:\s*\|\s*[^\s()|]+)*\)(?:\s|$)/

        def case_arm_glob = %r{(?<![[:alnum:]_./-])#{Regexp.escape(PATHS::DIRECTORY)}/\*\*?(?:/\*)?(?=\s*[|)])}o

        # A workflow is exempt only when every occurrence of the glob is an `on.<event>.paths` or `paths-ignore`
        # value. A matrix value, a `run:` script, YAML aliases, or a parse failure keeps it blocking.
        def note_glob_contexts(path, text)
          filtered_workflows << path if workflow_file?(path) && every_glob_filtered?(text)
          shell_scripts[path] = text if shell_script?(path, text)
        end

        def shell_script?(path, text)
          path.match?(/\.(?:sh|bash|zsh)\z/) || text.match?(%r{\A#!\S*(?:/|env\s+)(?:ba|z|da|k)?sh\b})
        end

        def every_glob_filtered?(text)
          occurrences = text.scan(terminal_glob).size
          occurrences.positive? && occurrences == filter_globs(text)
        end

        def filter_globs(text)
          events = workflow_events(text).values.grep(Hash)
          filters = events.flat_map { |event| event.values_at('paths', 'paths-ignore') }
          filters.flatten.count { |value| value.is_a?(String) && value.match?(whole_glob_value) }
        end

        # YAML 1.1 reads an unquoted `on` key as true.
        def workflow_events(text)
          document = YAML.safe_load(text, permitted_classes: [], permitted_symbols: [], aliases: false)
          events = document.is_a?(Hash) ? document.fetch('on') { document[true] } : nil
          events.is_a?(Hash) ? events : {}
        rescue Psych::Exception
          {}
        end

        def filtered_workflows = (@filtered_workflows ||= [])

        def shell_scripts = (@shell_scripts ||= {})

        def workflow_file?(path) = path.to_s.match?(%r{\A\.github/workflows/[^/]+\.ya?ml\z})

        def ignore_or_owners_file?(path)
          name = File.basename(path.to_s)
          name == 'CODEOWNERS' || name.match?(/\A\.[\w-]*ignore\z/)
        end

        def terminal_glob
          %r{(?<![[:alnum:]_.-])#{Regexp.escape(PATHS::DIRECTORY)}/\*\*(?![[:alnum:]_./*?\[\{-])}o
        end

        def whole_glob_value = %r{\A!?/?#{Regexp.escape(PATHS::DIRECTORY)}/\*\*\z}o

        def ignore_glob_entry
          %r{^(?<prefix>[ \t]*!?/?)#{Regexp.escape(PATHS::DIRECTORY)}/\*\*(?![[:alnum:]_./*?\[\{-])}o
        end
      end
    end
  end
end
