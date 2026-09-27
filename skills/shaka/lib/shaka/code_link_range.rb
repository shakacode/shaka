# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Finds the 1-based line range a walkthrough code link names, by text rather than number.
  module CodeLinkRange
    CLOSER = /\A(?:end\b|\})/
    CONTINUATION = /\A[)\]]/

    module_function

    def find(lines, from, to: nil, block: false)
      start = unique_line(lines, from)
      finish = if block then block_end(lines, start)
               elsif to then later_line(lines, start, to)
               else start
               end
      [start + 1, finish + 1]
    end

    def unique_line(lines, text)
      matches = lines.each_index.select { |index| lines[index].include?(text) }
      return matches.first if matches.size == 1

      raise Error, "#{text.inspect} matches #{matches.size} lines; use unique text."
    end

    def later_line(lines, start, text)
      found = ((start + 1)...lines.size).find { |index| lines[index].include?(text) }
      return found if found

      raise Error, "no line after #{lines[start].strip.inspect} contains #{text.inspect}."
    end

    # The block ends at the next line indented no deeper than its first line. A closing
    # `end` or brace belongs to the block; a closing parenthesis or bracket finishes a
    # multi-line signature, so the block continues; any other line starts the next one.
    def block_end(lines, start)
      depth = indentation(lines[start])
      last = start
      ((start + 1)...lines.size).each do |index|
        case block_line(lines[index], depth)
        when :inside then last = index
        when :closer then return index
        when :outside then return last
        end
      end
      last
    end

    def block_line(line, depth)
      text = line.strip
      return :blank if text.empty?
      return :inside if indentation(line) > depth || text.match?(CONTINUATION)

      text.match?(CLOSER) ? :closer : :outside
    end

    def indentation(line) = line[/\A[ \t]*/].size
  end
end
