# frozen_string_literal: true

require_relative '../error'
require_relative 'steps_besides_merging'

module Shaka
  # Orders description sections by the pull request template once the template holds a Shaka heading.
  # Each `##` heading the template names shows there; `## Shaka` folds the rest and `## Shaka Inline` shows them.
  module TemplateLayout
    COLLAPSED = 'shaka'
    INLINE = 'shaka inline'
    MARKER_LINE = /\A<!--.*-->\z/

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

    # The fold never hides a step someone must take before or after merging.
    def group(blocks, mode)
      return blocks if mode == INLINE

      shown, folded = blocks.partition { heading(it) == key(StepsBesidesMerging::HEADING) }
      return shown if folded.empty?

      [*shown, "<details>\n<summary>Shaka</summary>\n\n#{folded.join("\n\n")}\n\n</details>"]
    end

    def refuse_marker!(blocks)
      return unless blocks.any? { marker?(heading(it)) }

      raise Error, 'Publication sections cannot use a Shaka heading: in the pull request template it marks ' \
                   'where Shaka places its own sections. Leave it out of sections.'
    end

    # The heading that opens a block, after any marker comments; nil for a block without one.
    def heading(block)
      line = block.each_line(chomp: true).find { !it.match?(MARKER_LINE) }
      key(line.delete_prefix('## ')) if line&.start_with?('## ')
    end

    def key(text) = text.gsub(/<[^>]*>/, '').gsub(/[[:space:]]+/, ' ').strip.downcase

    def marker?(name) = [COLLAPSED, INLINE].include?(name)
  end
end
