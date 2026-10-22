# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Tools that stay in the old command directory while its Shaka wrappers move.
      module UnmovedTools
        private

        def scan_unmoved_tool(path, text)
          return unless path.start_with?("#{PATHS::COMMAND_DIRECTORY}/")
          return unless invocation_relative?(unmoved_tool_text(path, text)) || relative_command_call?(text)

          @references << { 'path' => path, 'kind' => 'unmoved tool dependency', 'paths' => [] }
          @blockers << "#{path}: tool uses an invocation-relative path; check moved sibling commands explicitly"
        end

        # The tool stays put, so finding the root or requiring a file that does not move keeps its meaning.
        def unmoved_tool_text(path, text)
          text.gsub(%r{#{script_parent}(?![[:alnum:]_./-])}o, '').gsub(ruby_root_expression, '')
              .gsub(/\brequire_relative[ (]*(['"])([^'"\#$\\]+)\1/) do |call|
                moved_require?(path, ::Regexp.last_match(2)) ? call : ''
              end
        end

        def moved_require?(path, target)
          resolved = File.expand_path(target, "/#{File.dirname(path)}").delete_prefix('/')
          [resolved, "#{resolved}.rb"].any? { |candidate| moved_beneath(candidate).any? }
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
