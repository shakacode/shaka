# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # References whose behavior depends on the old command directory.
      module ReferenceDependencies
        private

        def scan_symlink_reference(path)
          resolved = File.realpath(File.join(@root, path))
          return unless resolved.start_with?("#{@root}/")

          target = resolved.delete_prefix("#{@root}/")
          affected = moved_beneath(target)
          return if affected.empty?

          @references << { 'path' => path, 'kind' => 'inbound symlink', 'paths' => affected }
          @blockers << "#{path}: symlink targets moved path #{target}; repair the link explicitly"
        rescue Errno::ENOENT, Errno::ELOOP
          nil
        end

        def moved_beneath(target)
          @moves.filter_map do |move|
            source = move.fetch('from')
            source if source == target || source.start_with?("#{target}/")
          end
        end

        def scan_unmoved_tool(path, text)
          return unless path.start_with?("#{PATHS::COMMAND_DIRECTORY}/")
          return unless invocation_relative?(text) || relative_command_call?(text)

          @references << { 'path' => path, 'kind' => 'unmoved tool dependency', 'paths' => [] }
          @blockers << "#{path}: tool uses an invocation-relative path; check moved sibling commands explicitly"
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
