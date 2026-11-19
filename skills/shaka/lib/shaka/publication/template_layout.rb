# frozen_string_literal: true

require_relative 'human_comments'
require_relative 'risk_review'
require_relative 'steps_besides_merging'

module Shaka
  # Orders a description by the pull request template once the template marks a spot for Shaka.
  # Shaka's sections stay one sequence in their usual order at that spot. The template orders the agent's own
  # sections around them by heading, matched as data, so no rendered Markdown is read here.
  module TemplateLayout
    # What PrTemplate.outline puts where the template holds the marker line.
    MARKER = :shaka
    # Headings Shaka writes itself. A supplied section using one stays after Shaka's, so the template never puts
    # it ahead of the section it repeats.
    SHAKA_HEADINGS = ['Summary', 'Intent', 'Verification', 'Shaka metrics', RiskReview::HEADING.delete_prefix('## '),
                      HumanComments::HEADING, *StepsBesidesMerging::RESERVED_HEADINGS].map(&:downcase).freeze

    module_function

    # `sections` pairs each supplied section with its rendered block. Without the marker, they follow Shaka's,
    # as they always have.
    def arrange(shaka, sections, outline)
      entries = entries(outline)
      return [*shaka, *sections.map(&:last)] unless entries.include?(MARKER)

      named, unnamed = sections.partition { |section, _| entries.include?(placeable(section['heading'])) }
      entries.flat_map { |entry| entry == MARKER ? [*shaka, *unnamed.map(&:last)] : blocks(named, entry) }
    end

    # The template's entries in order, each heading by its key, keeping the first of a repeat.
    def entries(outline) = Array(outline).map { it == MARKER ? it : key(it) }.uniq

    def blocks(named, entry) = named.select { |section, _| key(section['heading']) == entry }.map(&:last)

    # A supplied heading's key, or nil for one Shaka writes itself, which the template does not place.
    def placeable(heading) = (name = key(heading)) && !SHAKA_HEADINGS.include?(name) ? name : nil

    # Headings match by their words, ignoring case, spacing, and Markdown's optional closing `#` marks.
    def key(text) = text.to_s.gsub(/[[:space:]]+/, ' ').strip.sub(/ #+\z/, '').downcase
  end
end
