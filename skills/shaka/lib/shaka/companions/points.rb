# frozen_string_literal: true

require_relative '../error'

module Shaka
  module Companions
    # Skill points are declared only by `Skill point` lines in the packaged procedures. Each
    # line runs `companions FILE#HEADING`, naming its own file and the heading it sits under.
    module Points
      REFERENCES = File.expand_path('../../../references', __dir__)
      LINE = /\ASkill point\b.*?`companions ([^\s`]+)/
      HEADING = /\A\#{1,6} +(.+?) *#*\z/
      FENCE = /\A {0,3}(`{3,}|~{3,})/

      Declaration = Data.define(:id, :file, :line, :heading_anchor) do
        def place = "#{File.basename(file, '.md')}##{heading_anchor}"
        def problem = "#{File.basename(file)}:#{line} names #{id} under ##{heading_anchor}"
      end

      module_function

      # { id => Declaration } for the packaged procedures, refusing any line whose id does not
      # match its file and heading, or that repeats another line's id.
      def all(directory = REFERENCES)
        declarations = Dir.glob(File.join(directory, '*.md')).flat_map { |path| scan(path) }
        problems = mismatches(declarations)
        raise Error, "Skill point lines do not match their place: #{problems.join('; ')}" unless problems.empty?

        declarations.to_h { |declaration| [declaration.id, declaration] }
      end

      def mismatches(declarations)
        wrong = declarations.reject { |declaration| declaration.id == declaration.place }.map(&:problem)
        repeated = declarations.group_by(&:id).select { |_id, list| list.length > 1 }.keys
        wrong + repeated.map { |id| "#{id} is declared more than once" }
      end

      # A point line may wrap, so its whole paragraph is read from the `Skill point` start.
      def scan(path)
        lines = File.readlines(path, chomp: true)
        anchor = nil
        outside_fences(lines).filter_map do |text, index|
          heading = text.match(HEADING)
          anchor = anchor(heading[1]) if heading
          point = paragraph(lines, index).match(LINE) if text.start_with?('Skill point')
          Declaration.new(point[1], path, index + 1, anchor) if point
        end
      end

      # A fence closes only on a bare run of its own character at least as long as the one that opened it.
      def outside_fences(lines)
        open = nil
        lines.each_with_index.reject do |text, _index|
          run = text[FENCE, 1]
          next(open = run) unless open

          open = nil if closes?(open, run, text)
          true
        end
      end

      def closes?(open, run, text) = run && run[0] == open[0] && run.length >= open.length && text.strip == run

      # A paragraph ends at a blank line or a code fence, so an example below it is never part of it.
      def paragraph(lines, start)
        lines.drop(start).take_while { |text| !text.strip.empty? && !text.match?(FENCE) }.join(' ')
      end

      # GitHub's heading anchor: lowercase, punctuation dropped, spaces as hyphens.
      def anchor(heading) = heading.downcase.gsub(/[^\p{Word}\- ]/, '').tr(' ', '-')
    end
  end
end
