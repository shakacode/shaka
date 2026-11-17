# frozen_string_literal: true

require_relative '../error'
require_relative 'human_comments'
require_relative 'intent_verification'
require_relative 'steps_besides_merging'
require_relative 'wip_details'

module Shaka
  # Orders description sections by the pull request template once the template holds a Shaka heading.
  # Each `##` heading the template names shows there; `## Shaka` folds the rest and `## Shaka Inline` shows them.
  module TemplateLayout
    COLLAPSED = 'shaka'
    INLINE = 'shaka inline'
    VERIFICATION = 'verification'
    IN_VIEW = ['summary', VERIFICATION, StepsBesidesMerging::HEADING.downcase, HumanComments::HEADING.downcase].freeze

    module_function

    # Blocks keep their order unless the template places them, so a template without the heading changes nothing.
    def arrange(blocks, headings)
      keys = Array(headings).map { key(it) }.uniq
      mode = keys.find { marker?(it) }
      return blocks unless mode

      refuse_marker!(blocks)
      placed, rest = place(with_evidence(blocks), keys)
      keys.flat_map { |name| name == mode ? group(rest, mode) : placed.fetch(name, []) }
    end

    # The blocks the template names, by heading, and the rest in their usual order.
    def place(blocks, keys)
      placed, rest = blocks.partition { keys.include?(heading(it)) }
      [placed.group_by { heading(it) }, rest]
    end

    # The folded evidence belongs to Verification, so the two move together wherever the template puts them.
    def with_evidence(blocks)
      evidence = blocks.find { it.start_with?(fold(IntentVerification::EVIDENCE_SUMMARY)) }
      return blocks unless evidence && blocks.any? { heading(it) == VERIFICATION }

      (blocks - [evidence]).map { heading(it) == VERIFICATION ? "#{it}\n\n#{evidence}" : it }
    end

    # The fold never hides what a reader acts on: the summary, verification and its gaps, steps besides
    # merging, people's comments, and an unfinished PR's WIP Details stay in view above it.
    def group(blocks, mode)
      return blocks if mode == INLINE

      shown, folded = blocks.partition { IN_VIEW.include?(heading(it)) || it.start_with?(fold(WipDetails::SUMMARY)) }
      return shown if folded.empty?

      [*shown, "#{fold('Shaka')}\n\n#{folded.join("\n\n")}\n\n</details>"]
    end

    def fold(summary) = "<details>\n<summary>#{summary}</summary>"

    def refuse_marker!(blocks)
      return unless blocks.any? { marker?(heading(it)) }

      raise Error, 'Publication sections cannot use a Shaka heading: in the pull request template it marks ' \
                   'where Shaka places its own sections. Leave it out of sections.'
    end

    # The heading that opens a block, after the one-line marker comments Shaka puts above some sections, read
    # as GitHub shows it, without closing hashes; nil for a block without one.
    def heading(block)
      line = block.each_line(chomp: true).find { !(it.start_with?('<!--') && it.end_with?('-->')) }
      key(line.delete_prefix('## ').sub(/[ \t]+#+[ \t]*\z/, '')) if line&.start_with?('## ')
    end

    # Headings match by their words, ignoring case and spacing.
    def key(text) = text.gsub(/[[:space:]]+/, ' ').strip.downcase

    def marker?(name) = [COLLAPSED, INLINE].include?(name)
  end
end
