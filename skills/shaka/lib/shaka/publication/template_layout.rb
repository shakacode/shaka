# frozen_string_literal: true

require_relative '../error'
require_relative 'intent_verification'

module Shaka
  # Orders description sections by the pull request template once the template holds a `## Shaka` heading.
  # Each `##` heading the template names shows there, and Shaka's other sections go to the Shaka heading.
  module TemplateLayout
    MARKER = 'shaka'
    VERIFICATION = 'verification'

    module_function

    # Blocks keep their order unless the template places them, so a template without the heading changes nothing.
    def arrange(blocks, headings)
      keys = Array(headings).map { key(it) }.uniq
      return blocks unless keys.include?(MARKER)

      refuse_marker!(blocks)
      placed, rest = place(with_evidence(blocks), keys)
      keys.flat_map { |name| name == MARKER ? rest : placed.fetch(name, []) }
    end

    # The blocks the template names, by heading, and the rest in their usual order.
    def place(blocks, keys)
      placed, rest = blocks.partition { keys.include?(heading(it)) }
      [placed.group_by { heading(it) }, rest]
    end

    # The evidence fold belongs to Shaka's own Verification, the last one before it, so the two move together.
    def with_evidence(blocks)
      at = blocks.index { it.start_with?("<details>\n<summary>#{IntentVerification::EVIDENCE_SUMMARY}</summary>") }
      owner = at && blocks[0...at].rindex { heading(it) == VERIFICATION }
      return blocks unless owner

      blocks.each_with_index.filter_map do |block, index|
        next if index == at

        index == owner ? "#{block}\n\n#{blocks[at]}" : block
      end
    end

    def refuse_marker!(blocks)
      return unless blocks.any? { heading(it) == MARKER }

      raise Error, 'Publication sections cannot use a Shaka heading: in the pull request template it marks ' \
                   'where Shaka places its own sections. Leave it out of sections.'
    end

    # The heading that opens a block, after the one-line marker comments Shaka puts above some sections, read
    # as GitHub shows it: without a trailing comment or closing hashes. Nil for a block without one.
    def heading(block)
      line = block.each_line(chomp: true).find { !(it.start_with?('<!--') && it.end_with?('-->')) }
      return unless line&.start_with?('## ')

      key(line.delete_prefix('## ').split('<!--', 2).first.to_s.sub(/[ \t]+#+[ \t]*\z/, ''))
    end

    # Headings match by their words, ignoring case and spacing.
    def key(text) = text.gsub(/[[:space:]]+/, ' ').strip.downcase
  end
end
