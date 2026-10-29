# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Tools that stay in the old command directory while its Shaka wrappers move.
      module UnmovedTools
        # A glob means slightly different things to a shell and to an ignore file, so the old directory routes a
        # moved command when any reading matches it, and the new one reaches it only when every reading does.
        GLOB_READINGS = [0, File::FNM_PATHNAME].freeze

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

        # Beside the repository's own tools the command directory stays, so code naming it keeps its meaning, unless
        # the line enters it, names a moved command, or globs over moved commands without also reaching them in the
        # new directory. Prose still describes where the wrappers live, so it keeps blocking.
        def retained_command_directory?(line, path)
          return false unless retained_code?(path)
          return false if line.match?(command_directory_change) || line.match?(moved_command_name) ||
                          line.match?(composed_command_path)

          !routes_moved_command?(line) || (reaches_every_moved_command?(line) && !earlier_arm_captures?(line, path))
        end

        # A shell `case` takes the first arm that matches, so an earlier arm over the new layout can take a moved
        # command before this one reaches it.
        def earlier_arm_captures?(line, path)
          text = shell_scripts[path]
          return false unless text

          earlier = text[0, text.index(line) || text.size].each_line.grep(case_arm).join
          moved_command_names.any? { |name| glob_matches?(new_layout_globs(earlier), "bin/#{name}", :any?) }
        end

        def routes_moved_command?(line)
          globs = line.scan(glob_under(PATHS::COMMAND_DIRECTORY)).flatten
          moved_command_names.any? { |name| glob_matches?(globs, name, :any?) }
        end

        def reaches_every_moved_command?(line)
          moved_command_names.all? { |name| glob_matches?(new_layout_globs(line), "bin/#{name}", :all?) }
        end

        def new_layout_globs(text) = text.scan(glob_under(File.dirname(PATHS::NEW_CONTRACT))).flatten

        # `readings` is :any? or :all? of the GLOB_READINGS.
        def glob_matches?(globs, path, readings)
          globs.any? { |glob| GLOB_READINGS.public_send(readings) { |flags| File.fnmatch?(glob, path, flags) } }
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

        # The pattern part of each glob written under a directory, such as `*.md` or `**/*`.
        def glob_under(directory)
          %r{(?<![[:alnum:]_.-])#{Regexp.escape(directory)}/([^\s|)'"(]*[*?\[][^\s|)'"(]*)}
        end

        # A name filled in at run time, or joined or appended as a variable, may be a moved command.
        def composed_command_path
          directory = Regexp.escape(PATHS::COMMAND_DIRECTORY)
          @composed_command_path ||=
            %r{#{directory}(?:/['"]?(?:\#\{|\$|\{|%)|/?['"]?\s*(?:\+|<<|,\s*(?:[^'"\s]|$))|['"]\)?\s*/\s*\w)}
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
