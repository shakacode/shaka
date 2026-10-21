# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Conservative root calculation repairs for known wrapper patterns.
      module RootRepair
        ROOT_VARIABLE = /\$\{?root\b|(?<![\w$])root=/

        private

        def repair_root(text)
          if text.include?(OLD_ROOT)
            return [nil, nil] unless exits_on_error?(text, text.index(OLD_ROOT))

            return [text.sub(OLD_ROOT, GIT_ROOT), 'recognized shell root discovery']
          end
          shell = shell_root_lookup(text)
          return custom_shell_root(shell) if shell
          return custom_ruby_root(text) if text.match?(ruby_root_pattern)
          return [nil, nil] if ambiguous_root?(text)

          [text, nil]
        end

        def exits_on_error?(text, offset)
          text[0...offset].lines.reduce(false) do |enabled, line|
            next true if line.match?(/^\s*set\s+-(?:[a-zA-Z]*e[a-zA-Z]*|o\s+errexit)(?:\s|$)/)
            next false if line.match?(/^\s*set\s+\+(?:[a-zA-Z]*e[a-zA-Z]*|o\s+errexit)(?:\s|$)/)

            enabled
          end
        end

        # A failed lookup inside `cd "$(...)"` would leave `cd ""`, which shells treat as success,
        # so an inline change of directory becomes a lookup that exits on failure, then `cd "$root"`.
        def shell_root_lookup(text)
          match = text.match(shell_root_pattern) || text.match(inline_root_pattern)
          return unless match && exits_on_error?(text, match.begin(0))
          return match if match.names.include?('assignment') || !text.match?(ROOT_VARIABLE)

          nil
        end

        def custom_shell_root(match)
          indent = match[:indent]
          replacement = "#{indent}#{GIT_ROOT}"
          replacement += %(\n#{indent}cd "$root") unless match.names.include?('assignment')
          ["#{match.pre_match}#{replacement}#{match.post_match}", 'custom shell root discovery']
        end

        def custom_ruby_root(text)
          result = text.sub(ruby_root_pattern) do
            match = ::Regexp.last_match
            expression = match[:expression].start_with?('Pathname') ? "Pathname(#{RUBY_GIT_ROOT})" : RUBY_GIT_ROOT
            indent = match[:indent]
            assignment = "#{indent}root = #{expression}"
            failure = "#{indent}abort 'Cannot find repository root' unless $?.success? && !root.to_s.empty?"
            "#{assignment}\n#{failure}"
          end
          [result, 'custom Ruby root discovery']
        end

        def shell_root_pattern
          lookup = "#{script_parent}|\"#{script_parent}\"|#{changed_parent}|\"#{changed_parent}\""
          /^(?<indent>[ \t]*)(?<assignment>root=)(?:#{lookup})[ \t]*$/
        end

        def inline_root_pattern = /^(?<indent>[ \t]*)cd (?:-P )?(?:-- )?"#{script_parent}"[ \t]*$/

        def changed_parent = "\\$\\((?:CDPATH= )?cd (?:-P )?(?:-- )?\"#{script_parent}\" && pwd(?: -P)?\\)"

        # Two levels above the script; `$0` and `${BASH_SOURCE[0]}` agree for an executed wrapper.
        def script_parent = '\\$\\(dirname (?:--? )?"(?:\\$0|\\$\\{BASH_SOURCE\\[0\\]\\})"\\)/\\.\\./\\.\\.'

        def ruby_root_pattern
          file = "File\\.expand_path\\(['\"]\\.\\./\\.\\.['\"], __dir__\\)"
          pathname = 'Pathname\\(__dir__\\)\\.parent\\.parent'
          /^(?<indent>[ \t]*)root = (?<expression>#{file}|#{pathname})[ \t]*$/
        end

        # Names the replacement for a shell root lookup the repair does not recognize.
        def root_repair_hint(text)
          line = text.lines.find { |candidate| candidate.include?('../..') }&.strip
          return 'repair it explicitly' if line.nil? || shebang_command(text.lines.first.to_s) == 'ruby'

          name = line[/\A(?:export[ \t]+)?([A-Za-z_]\w*)=/, 1]
          lookup = name ? "#{name}=#{GIT_ROOT.delete_prefix('root=')}" : %(#{GIT_ROOT}; cd "$root")
          "after `set -e`, replace `#{line}` with `#{lookup}`"
        end

        def ambiguous_root?(text)
          text.include?('../..') || text.include?('Pathname(__dir__).parent.parent')
        end

        def invocation_relative?(text)
          remaining = text.gsub(GIT_ROOT, '').gsub(RUBY_GIT_ROOT, '')
          shell = /\$(?:0\b|\{0[^}]*\})|\bBASH_SOURCE\b/
          ruby = /\b__dir__\b|\b__FILE__\b|\b__file__\b|\brequire_relative\b|\$PROGRAM_NAME\b/
          remaining.match?(shell) || remaining.match?(ruby)
        end
      end
    end
  end
end
