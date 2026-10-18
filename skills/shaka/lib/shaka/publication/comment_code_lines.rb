# frozen_string_literal: true

module Shaka
  module CommentExcerpt
    # Follows which lines of a comment GitHub renders as code: fenced and indented code blocks,
    # measured from the list item that holds them. Block quotes are left to the caller.
    class CodeLines
      # Three or more backticks or tildes open a fence; a backtick fence's info text has no backtick.
      FENCE = /\A(?<marker>`{3,}(?=[^`]*\z)|~{3,})/
      # A heading, a thematic break, or a setext underline ends a paragraph on its own line.
      ENDS_PARAGRAPH = /\A(?:\#{1,6}(?:\s|\z)|([-*_])(?:[ \t]*\1){2,}[ \t]*\z|(?:=+|-+)[ \t]*\z)/
      LIST_ITEM = /\A(?<marker>[-+*]|(?<number>\d{1,9})[.)])(?<gap>[ \t]+|\z)/

      def initialize
        @items = [] # the content column of each open list item, outermost first
        @fence = nil
        @fence_items = 0
        @fence_column = 0
        @paragraph = false
        @paragraph_in_list = false
      end

      def code?(line)
        text = line.chomp
        return blank? if text.strip.empty?

        column = columns(text)
        close_items(column) unless lazy?(text, column)
        return inside_fence?(text, column) if @fence

        block?(text.lstrip, column)
      end

      private

      def blank?
        @paragraph = false
        !@fence.nil?
      end

      # A line indented less than the innermost item ends it, unless it continues that item's paragraph.
      def lazy?(text, column)
        @paragraph && column < (@items.last || 0) && !block_start?(text.lstrip)
      end

      def block_start?(text)
        text.match?(FENCE) || text.match?(ENDS_PARAGRAPH) || text.start_with?('>') || text.match?(LIST_ITEM)
      end

      def close_items(column)
        @items.pop while @items.any? && column < @items.last
        @fence = nil if @fence && @items.size < @fence_items
      end

      # A line inside a fence is code. A run of the same character at least as long closes it,
      # indented at most three spaces past the fence's list item.
      def inside_fence?(text, column)
        closer = column - @fence_column <= 3 && text.strip.match?(/\A#{@fence}#{@fence[0]}*\z/)
        @fence = nil if closer
        true
      end

      def block?(text, column)
        offset = column - (@items.last || 0)
        return indented_code? if !@paragraph && offset >= 4
        return paragraph?(text) if offset > 3

        item = list_item(text)
        item ? item?(item, column) : content?(text, @items.last || 0)
      end

      def list_item(text)
        item = text.match(LIST_ITEM) unless text.match?(ENDS_PARAGRAPH)
        item if item && starts_list?(item)
      end

      def indented_code?
        @paragraph = false
        true
      end

      def paragraph?(text)
        @paragraph = !text.start_with?('>')
        @paragraph_in_list = @items.any?
        false
      end

      # Only a list that starts at one and holds text may interrupt a paragraph outside a list.
      def starts_list?(item)
        return true unless @paragraph && !@paragraph_in_list

        (item[:number].nil? || item[:number].to_i == 1) && item.post_match.match?(/\S/)
      end

      # An item's content starts after its marker and up to four spaces; more spaces start
      # indented code one space after the marker.
      def item?(item, column)
        rest = item.post_match
        content = column + item[:marker].size
        gap = columns(item[:gap])
        return content?(rest, start_item(content + gap)) if gap.between?(1, 4) && rest.match?(/\S/)

        start_item(content + 1)
        indented_code? && rest.match?(/\S/)
      end

      def start_item(column)
        @items.push(column)
        column
      end

      # A line at its container's left edge: a fence, a paragraph ender, or paragraph text.
      def content?(text, column)
        if (@fence = text[FENCE, :marker])
          @fence_items = @items.size
          @fence_column = column
          @paragraph = false
          return true
        end
        return paragraph?(text) unless text.match?(ENDS_PARAGRAPH)

        @paragraph = false
        false
      end

      # A tab advances to the next multiple of four columns.
      def columns(text)
        text[/\A[ \t]*/].each_char.reduce(0) { |column, space| space == "\t" ? ((column / 4) + 1) * 4 : column + 1 }
      end
    end
  end
end
