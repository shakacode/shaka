# frozen_string_literal: true

require_relative '../error'
require_relative 'captures'

module Shaka
  module UiCheck
    # Earlier UI evidence a newer check carries in a collapsed section, apart from what the
    # newer head shows. Each block keeps the text and revision of the check that captured it.
    module History
      OPEN = '<!-- shaka:ui-history -->'
      CLOSE = '<!-- /shaka:ui-history -->'
      SECTION = /\n*#{Regexp.escape(OPEN)}.*#{Regexp.escape(CLOSE)}\n*/m
      BLOCK = %r{^<!-- shaka:ui-history-from (\S+) (\S+) -->\n[^\n]*\n\n(.*?)\n<!-- /shaka:ui-history-from -->$}m
      REPLACED = '<!-- shaka:ui-replaced -->'
      RESERVED = %r{<!-- /?shaka:ui-(?:history|replaced)}
      HEADING = /\A# Verification\b[^\n]*\n+/
      UNKNOWN = 'unknown'

      Block = Data.define(:revision, :source, :text) do
        def marks = text.lines.select { |line| line.start_with?(REPLACED) }.map(&:strip)
        def unmarked = text.lines.reject { |line| line.start_with?(REPLACED) }.join.rstrip
        def replaced = marks.flat_map { |line| Captures.urls(line) }
        def pending = Captures.urls(text) - replaced
      end

      module_function

      # Each earlier check is { revision:, source:, body: } with the writer line and marker removed.
      # Blocks whose captures the new check shows again or retires are left in the folded comment.
      def carry(earlier, shown:, retired:, head:)
        blocks = gather(earlier)
        check_retired(blocks, retired)
        blocks.reject { |block| (block.pending - shown - retired).empty? }
              .map { |block| mark_replaced(block, block.pending & retired, head) }
      end

      # Two open checks carry the same older block when a fold failed. Copies differ only in the
      # replaced marks later checks added, so one copy keeps every mark any of them holds.
      def gather(earlier)
        earlier.flat_map { |check| blocks(check) }.group_by { |block| [block.revision, block.source] }
               .map { |_key, copies| merge_marks(copies) }
      end

      def merge_marks(copies)
        raise Error, "Copies of earlier evidence from #{copies.first.source} differ; fold the stale one by hand." if
          copies.map(&:unmarked).uniq.length > 1

        copies.first.with(text: [copies.first.unmarked, *copies.flat_map(&:marks).uniq].join("\n\n"))
      end

      # A capture already marked replaced may be retired again, as when a publish is retried.
      def check_retired(blocks, retired)
        unknown = retired - blocks.flat_map { |block| block.pending + block.replaced }
        raise Error, "Retired captures are not in an open earlier UI check: #{unknown.join(', ')}" if unknown.any?
      end

      def mark_replaced(block, replaced, head)
        return block if replaced.empty?

        block.with(text: "#{block.text}\n\n#{REPLACED} Replaced at `#{head[0, 7]}`: #{replaced.join(', ')}")
      end

      # History that does not parse must stop the publish, or its evidence would be folded away:
      # outside the parsed blocks no history marker or capture may remain, and a parsed block may
      # hold no history marker, which would mean it swallowed a neighbour.
      def blocks(check)
        body = check.fetch(:body)
        section = body[SECTION].to_s
        own = body.sub(SECTION, "\n").strip.sub(HEADING, '').strip
        check_parsed(own, section, check.fetch(:source))
        section.scan(BLOCK).map { |fields| Block.new(*fields) } +
          [Block.new(check.fetch(:revision) || UNKNOWN, check.fetch(:source), own)]
      end

      def check_parsed(own, section, source)
        rest = section.gsub(BLOCK, '').sub(OPEN, '').sub(CLOSE, '')
        swallowed = section.scan(BLOCK).any? { |_revision, _source, text| text.include?('shaka:ui-history') }
        return unless swallowed || reserved?(own) || reserved?(rest) || Captures.urls(rest).any?

        raise Error, "Earlier evidence in #{source} no longer parses; restore it or retire its captures by hand."
      end

      def reserved?(text) = text.match?(RESERVED)

      def render(blocks, head:, commit_url:)
        return '' if blocks.empty?

        "\n#{OPEN}\n<details>\n<summary>Earlier evidence, not checked at this head</summary>\n\n" \
          "Each capture below shows the revision named above it, not `#{head[0, 7]}`.\n\n" \
          "#{blocks.map { |block| render_block(block, commit_url) }.join("\n\n")}\n\n</details>\n#{CLOSE}\n"
      end

      def render_block(block, commit_url)
        heading = if block.revision == UNKNOWN
                    "#### From [an earlier UI check](#{block.source}), revision not recorded"
                  else
                    "#### Captured at [`#{block.revision[0, 7]}`](#{commit_url.call(block.revision)}) · " \
                      "[UI check](#{block.source})"
                  end
        "<!-- shaka:ui-history-from #{block.revision} #{block.source} -->\n#{heading}\n\n#{block.text}\n" \
          '<!-- /shaka:ui-history-from -->'
      end
    end
  end
end
