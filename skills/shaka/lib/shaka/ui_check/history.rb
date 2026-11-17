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
        def replaced = text.lines.select { |line| line.start_with?(REPLACED) }.flat_map { |line| Captures.urls(line) }
        def pending = Captures.urls(text) - replaced
      end

      module_function

      # Each earlier check is { revision:, source:, body: } with the writer line and marker removed.
      # Blocks whose captures the new check shows again or retires are left in the folded comment.
      def carry(earlier, shown:, retired:, head:)
        blocks = gather(earlier)
        unknown = retired - blocks.flat_map(&:pending)
        raise Error, "Retired captures are not in an open earlier UI check: #{unknown.join(', ')}" if unknown.any?

        blocks.reject { |block| (block.pending - shown - retired).empty? }
              .map { |block| mark_replaced(block, block.pending & retired, head) }
      end

      # Two open checks carry the same older block when a fold failed. Each newer copy only adds
      # replaced marks, so the copy with the most of them is the current one.
      def gather(earlier)
        earlier.flat_map { |check| blocks(check) }.group_by { |block| [block.revision, block.source] }
               .map { |_key, copies| copies.max_by { |block| block.replaced.length } }
      end

      def mark_replaced(block, replaced, head)
        return block if replaced.empty?

        block.with(text: "#{block.text}\n\n#{REPLACED} Replaced at `#{head[0, 7]}`: #{replaced.join(', ')}")
      end

      def blocks(check)
        body = check.fetch(:body)
        nested = body[SECTION].to_s.scan(BLOCK).map { |revision, source, text| Block.new(revision, source, text) }
        own = body.sub(SECTION, "\n").strip.sub(HEADING, '').strip
        nested + [Block.new(check.fetch(:revision) || UNKNOWN, check.fetch(:source), own)]
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
