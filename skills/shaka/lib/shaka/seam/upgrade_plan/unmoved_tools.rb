# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Tools that stay in the old command directory while its Shaka wrappers move.
      module UnmovedTools
        include CaseArms

        private

        def scan_unmoved_tool(path, text)
          return unless path.start_with?("#{PATHS::COMMAND_DIRECTORY}/")
          return unless invocation_relative?(unmoved_tool_text(path, text)) || relative_command_call?(text)

          @references << { 'path' => path, 'kind' => 'unmoved tool dependency', 'paths' => [] }
          @blockers << "#{path}: tool uses an invocation-relative path; check moved sibling commands explicitly"
        end

        # The tool stays put, so finding the root or requiring a file that does not move keeps its meaning.
        # Two levels up is the root only for a tool directly in the command directory.
        def unmoved_tool_text(path, text)
          if File.dirname(path) == PATHS::COMMAND_DIRECTORY
            text = text.gsub(%r{#{script_parent}(?![[:alnum:]_./-])}o, '').gsub(ruby_root_expression, '')
          end
          text.gsub(/\brequire_relative[ (]*(['"])([^'"\#$\\]+)\1/) do |call|
            moved_require?(path, ::Regexp.last_match(2)) ? call : ''
          end
        end

        def moved_require?(path, target)
          resolved = File.expand_path(target, "/#{File.dirname(path)}").delete_prefix('/')
          [resolved, "#{resolved}.rb"].any? { |candidate| moved_beneath(candidate).any? }
        end

        # Beside the repository's own tools the command directory stays, so two shapes keep their meaning: a line
        # that only creates the directory, and a shell `case` arm that routes each moved command the same way after
        # the move. Every other mention, and all prose, keeps blocking.
        def retained_command_directory?(line, path)
          return false unless retained_code?(path)
          return line.match?(directory_creation) unless shell_scripts.key?(path) && line.match?(case_arm)

          unchanged_arm?(line, path)
        end

        def retained_code?(path)
          !path.nil? && !markdown_path?(path) && @tracked_reference_paths && retained_command_file?
        end

        def moved_command_names
          @moved_command_names ||= @moves.filter_map do |move|
            source = move.fetch('from')
            File.basename(source) if source.start_with?("#{PATHS::COMMAND_DIRECTORY}/")
          end
        end

        def moved_command_name
          names = moved_command_names.map { |name| Regexp.escape(name) }
          @moved_command_name ||= names.empty? ? /(?!)/ : /(?<![[:alnum:]_.-])(?:#{names.join('|')})(?![[:alnum:]_-])/
        end

        # A name filled in at run time may be a moved command.
        def composed_command_path
          @composed_command_path ||= %r{#{Regexp.escape(PATHS::COMMAND_DIRECTORY)}/['"]?(?:\$|\{)}
        end

        def relative_command_call?(text)
          @moves.any? do |move|
            source = move.fetch('from')
            next unless source.start_with?("#{PATHS::COMMAND_DIRECTORY}/")

            text.match?(%r{(?<![[:alnum:]_./-])\./#{Regexp.escape(File.basename(source))}(?![[:alnum:]_./-])})
          end
        end
      end
    end
  end
end
