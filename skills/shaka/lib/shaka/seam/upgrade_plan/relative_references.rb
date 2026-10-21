# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Files inside the old directory can name moved files relative to themselves.
      module RelativeReferences
        private

        def rewrite_relative_references(path, text, executable)
          mapping = relative_mapping(path)
          return text if mapping.empty?

          text.lines.map { |line| rewrite_relative_line(path, line, mapping, executable) }.join
        end

        def rewrite_relative_line(path, line, mapping, executable)
          found = mapping.keys.select { |old| line.match?(relative_pattern(old)) }
          return line if found.empty?

          @references << { 'path' => path, 'kind' => 'relative old-layout reference',
                           'paths' => found.map { |old| mapping.fetch(old).last } }
          return historical_reference(path, line) if historical_line?(path, line)
          return block_relative_reference(path, found, line) if executable

          replace_relative(line, found, mapping)
        end

        def replace_relative(line, found, mapping)
          found.reduce(line) do |result, old|
            result.gsub(relative_pattern(old)) { "#{::Regexp.last_match[:lead]}#{mapping.fetch(old).first}" }
          end
        end

        def block_relative_reference(path, found, line)
          @blockers << "#{path}: relative old-layout reference #{found.join(', ')} needs explicit repair"
          line
        end

        def relative_reference_file?(path) = !relative_mapping(path).empty?

        # Maps each spelling to [new spelling, old path]. A bare command name is prose, so only
        # spellings with a slash and the two distinctive YAML names count.
        def relative_mapping(path)
          directory = File.dirname(path)
          return {} unless inside_old_directory?(directory)

          relative_targets.each_with_object({}) do |(old, new), mapping|
            spelling = relative_to(old, directory)
            mapping[spelling] = [relative_to(new, directory), old] if spelling.include?('/')
            mapping[File.basename(old)] ||= [relative_to(new, directory), old] if yaml_file?(old)
          end
        end

        def yaml_file?(path) = [PATHS::CONTRACT, PATHS::REPOSITORY_ALLOWLIST].include?(path)

        def inside_old_directory?(directory)
          new_directory = File.dirname(PATHS::NEW_CONTRACT)
          (directory == PATHS::DIRECTORY || directory.start_with?("#{PATHS::DIRECTORY}/")) &&
            directory != new_directory && !directory.start_with?("#{new_directory}/")
        end

        def relative_targets
          reference_mapping.merge("#{PATHS::COMMAND_DIRECTORY}/" => "#{PATHS::NEW_COMMAND_DIRECTORY}/")
        end

        def relative_to(target, directory)
          relative = Pathname(target).relative_path_from(Pathname(directory)).to_s
          target.end_with?('/') ? "#{relative}/" : relative
        end

        def relative_pattern(spelling)
          ending = spelling.end_with?('/') ? '(?![[:alnum:]_.-])' : path_end
          Regexp.new("(?<![[:alnum:]_./-])(?<lead>\\./)?#{Regexp.escape(spelling)}#{ending}")
        end
      end
    end
  end
end
