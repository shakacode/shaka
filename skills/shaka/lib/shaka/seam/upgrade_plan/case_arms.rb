# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Whether a shell `case` arm naming the old command directory routes each moved command the same way after
      # the move.
      module CaseArms
        # A glob reads differently to a shell `case`, whose `*` also matches a leading dot, and to an ignore file, so a
        # match counts as certain only when every reading agrees and as possible when any does.
        GLOB_READINGS = [0, File::FNM_PATHNAME, File::FNM_DOTMATCH].freeze

        private

        # A quoted pattern matches literally in a shell, and the arm's body runs like any other code, so either one
        # keeps the line blocking.
        def unchanged_arm?(line, path)
          patterns = arm_patterns(line)
          return false if patterns.any? { |pattern| pattern.match?(/['"\\]/) } || line.match?(moved_command_name)
          return false if command_directory_reference?(line.split(')', 2).last)

          captured = captured_arms(path)
          captured != :unclear && same_route?(patterns) && !captured.include?(line.chomp)
        end

        def directory_creation
          @directory_creation ||=
            %r{\A\s*mkdir\s+(?:-\w+\s+)*(['"]?)(?:\./)?#{Regexp.escape(PATHS::COMMAND_DIRECTORY)}/?\1\s*$}
        end

        def arm_patterns(line) = line[/\A\s*\(?([^)]*)\)/, 1].split('|').map(&:strip)

        # The arm matches each moved command at its new path wherever it matched it at the old one.
        def same_route?(patterns)
          moved_command_names.all? do |name|
            !arm_matches?(patterns, old_command(name), :any?) || arm_matches?(patterns, new_command(name), :all?)
          end
        end

        # A shell `case` takes the first arm that matches, so an earlier arm that newly matches a moved command
        # takes it from every later arm in that `case`, nested ones aside. Arms compare by text, so a repeated arm
        # counts if any copy is taken.
        # A file whose `case` statements cannot be read one header and one `esac` per line returns :unclear, and
        # then every arm keeps blocking.
        def captured_arms(path)
          (@captured_arms ||= {})[path] ||= begin
            text = shell_scripts.fetch(path)
            cases = [[]]
            if case_structure_clear?(text)
              text.each_line.with_object([]) { |line, captured| note_arm(line, cases, captured) }
            else
              :unclear
            end
          end
        end

        def case_structure_clear?(text)
          depth = text.each_line.reduce(0) do |open, line|
            change = case_depth_change(line)
            return false if change.nil? || (open + change).negative?

            open + change
          end
          depth.zero?
        end

        # One header or one `esac` per line; anything else, such as a one-line `case`, cannot be read here.
        def case_depth_change(line)
          return 0 if line.match?(/\A\s*#/)

          starts = line.scan(/\bcase\b/).size
          ends = line.scan(/\besac\b/).size
          return if starts + ends > 1 || (starts == 1 && !line.match?(case_header)) || hidden_arm?(line)

          starts - ends
        end

        # A second arm after `;;`, or an extglob arm, holds patterns this reader does not record.
        def hidden_arm?(line) = line.match?(/;;\s*[^\s#]/) || line.match?(/\A\s*\(?\s*[@!+*?]\(/)

        # Any line opening with a pattern list and `)`, spaced or not, is an arm whose patterns count.
        def arm_line = /\A\s*\(?\s*[^\s()#][^()]*\)/

        def case_header = /\A\s*case\s.*\sin\s*$/

        # `cases` holds the arms seen so far in each open `case`, innermost last.
        def note_arm(line, cases, captured)
          cases.push([]) if line.match?(case_header)
          if line.match?(arm_line)
            captured << line.chomp if takes_moved_command?(cases.last)
            cases.last.concat(arm_patterns(line))
          end
          cases.pop if line.match?(/\besac\b/) && cases.size > 1
        end

        # An earlier pattern that quotes, escapes, or expands a variable cannot be read here, so it may take any
        # command.
        def takes_moved_command?(patterns)
          return true if patterns.any? { |pattern| pattern.match?(/['"\\$`]/) }

          moved_command_names.any? do |name|
            arm_matches?(patterns, new_command(name), :any?) && !arm_matches?(patterns, old_command(name), :all?)
          end
        end

        def old_command(name) = "#{PATHS::COMMAND_DIRECTORY}/#{name}"

        def new_command(name) = "#{PATHS::NEW_COMMAND_DIRECTORY}/#{name}"

        # `readings` is :any? or :all? of the GLOB_READINGS.
        def arm_matches?(patterns, path, readings)
          patterns.any? do |pattern|
            GLOB_READINGS.public_send(readings) { |flags| File.fnmatch?(pattern, path, flags) }
          end
        end
      end
    end
  end
end
