# frozen_string_literal: true

require_relative '../error'
require_relative 'human_comments'
require_relative 'steps_besides_merging'
require_relative 'wip_details'

module Shaka
  # Orders description sections by the pull request template once the template holds a Shaka heading.
  # Each `##` heading the template names shows there; `## Shaka` folds the rest and `## Shaka Inline` shows them.
  module TemplateLayout
    COLLAPSED = 'shaka'
    INLINE = 'shaka inline'
    IN_VIEW = ['summary', StepsBesidesMerging::HEADING.downcase, HumanComments::HEADING.downcase].freeze

    module_function

    # Blocks keep their order unless the template places them, so a template without the heading changes nothing.
    def arrange(blocks, headings)
      keys = Array(headings).map { key(it) }.uniq
      mode = keys.find { marker?(it) }
      return blocks unless mode

      refuse_marker!(blocks)
      placed, rest = blocks.partition { keys.include?(heading(it)) }
      placed = placed.group_by { heading(it) }
      keys.flat_map { |name| name == mode ? group(rest, mode) : placed.fetch(name, []) }
    end

    # The fold never hides what a reader acts on: the summary, steps besides merging, people's comments,
    # and an unfinished PR's WIP Details stay in view above it.
    def group(blocks, mode)
      return blocks if mode == INLINE

      shown, folded = blocks.partition { in_view?(it) }
      return shown if folded.empty?

      [*shown, "<details>\n<summary>Shaka</summary>\n\n#{folded.join("\n\n")}\n\n</details>"]
    end

    def in_view?(block)
      IN_VIEW.include?(heading(block)) || block.start_with?("<details>\n<summary>#{WipDetails::SUMMARY}</summary>")
    end

    def refuse_marker!(blocks)
      return unless blocks.any? { marker?(heading(it)) }

      raise Error, 'Publication sections cannot use a Shaka heading: in the pull request template it marks ' \
                   'where Shaka places its own sections. Leave it out of sections.'
    end

    # The heading that opens a block, after the one-line marker comments Shaka puts above some sections;
    # nil for a block without one.
    def heading(block)
      line = block.each_line(chomp: true).find { !(it.start_with?('<!--') && it.end_with?('-->')) }
      key(line.delete_prefix('## ')) if line&.start_with?('## ')
    end

    # Headings match by their words, ignoring case and spacing.
    def key(text) = text.gsub(/[[:space:]]+/, ' ').strip.downcase

    def marker?(name) = [COLLAPSED, INLINE].include?(name)
  end
end
