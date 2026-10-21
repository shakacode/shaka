# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Renders description sections, including the decisions list that owns one heading.
  class PublicationSections
    DECISIONS_HEADING = 'Decisions to make'
    # GitHub gives comment headings no anchor, so the heading carries one; GitHub prefixes its id.
    DECISIONS_ANCHOR = 'decisions-to-make'
    DECISIONS_LINK = "[#{DECISIONS_HEADING}](#user-content-#{DECISIONS_ANCHOR})".freeze
    HEADINGS = [DECISIONS_HEADING, 'Decisions for the maintainer'].freeze
    MARKER = '<!-- shaka:decisions -->'

    # The open decisions render with the checkpoint, so following leads the agent's own sections.
    def self.render(content, following = [])
      listed = PublicationText.list(content['sections'], 'sections')
      refuse_heading(listed)
      [*following, *listed.map { |section| section_block(section) }]
    end

    def self.decisions(items)
      listed = PublicationText.list(items, 'decisions')
      return [] if listed.empty?

      lines = listed.map { |item| "- #{PublicationText.single_line(item, 'decision')}" }
      ["#{MARKER}\n## #{DECISIONS_HEADING}<a id=\"#{DECISIONS_ANCHOR}\"></a>\n\n#{lines.join("\n")}"]
    end

    def self.refuse_heading(sections)
      return unless sections.any? { |section| decisions_heading?(section) }

      raise Error, 'Publication decisions must be supplied as the decisions list, not a section.'
    end

    def self.decisions_heading?(section)
      section.is_a?(Hash) && HEADINGS.any? { |heading| section['heading'].to_s.strip.casecmp?(heading) }
    end

    def self.section_block(section)
      heading = PublicationText.single_line(section['heading'], 'section heading')
      "## #{heading}\n\n#{PublicationText.required(section['body'], "section #{heading}")}"
    end

    private_class_method :refuse_heading, :decisions_heading?, :section_block
  end
end
