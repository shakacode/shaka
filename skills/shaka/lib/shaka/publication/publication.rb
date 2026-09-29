# frozen_string_literal: true

require_relative '../error'
require_relative 'text'
require_relative 'links'
require_relative 'usage_details'
require_relative 'provenance'
require_relative 'wip_details'
require_relative '../publication_sections'

module Shaka
  # Renders the publication surfaces so headings, spacing, tables and details are Ruby's.
  class Publication
    def self.description(content)
      new(content, require_tables: true).render(%i[top_links sections table provenance details wip])
    end

    def self.comment(content) = new(content).render([])
    def self.walkthrough(content) = new(content).render(%i[sections table details revision], title: true)

    def initialize(content, require_tables: false)
      raise Error, 'Publication content must be an object.' unless content.is_a?(Hash)

      @content = content
      @require_tables = require_tables
    end

    def render(parts, title: false)
      blocks = [PublicationText.identity(@content['identity'])]
      blocks << '# Code Walkthrough' if title
      blocks << PublicationText.required(@content['summary'], 'summary')
      parts.each { |part| blocks.concat(send(part)) }
      "#{blocks.join("\n\n")}\n"
    end

    private

    def sections = PublicationSections.render(@content)

    def top_links = PublicationLinks.top(@content)

    def table
      spec = @content['table']
      if spec.nil?
        raise Error, 'Publication description requires a table.' if @require_tables

        return []
      end

      columns = table_columns(spec)
      rows = table_data_rows(spec, columns.size)
      [[table_line(columns), table_line(['---'] * columns.size), *rows].join("\n")]
    end

    def table_data_rows(spec, width)
      rows = PublicationText.list(spec['rows'], 'table rows')
      raise Error, 'Publication table must include at least one row.' if rows.empty?

      rows.map { |row| table_row(row, width) }
    end

    def table_columns(spec)
      columns = spec.is_a?(Hash) ? PublicationText.list(spec['columns'], 'table columns') : []
      raise Error, 'Publication table must define at least one column.' if columns.empty?

      columns.map { |column| PublicationText.single_line(column, 'table column') }
    end

    def table_row(row, width)
      cells = PublicationText.list(row, 'table row')
      raise Error, "Publication table row has #{cells.size} cells; #{width} columns are defined." if cells.size != width

      table_line(cells.map { |cell| PublicationText.single_line(cell.to_s, 'table cell') })
    end

    # Escaping pipes keeps a cell from silently adding a column.
    def table_line(cells) = "| #{cells.map { |cell| cell.gsub('|', '\\|') }.join(' | ')} |"

    def details
      items = PublicationText.list(@content['details'], 'details')
      if @require_tables
        refuse_free_form_usage(items)
        refuse_free_form_wip(items)
      end
      rendered = items.map { |detail| details_block(detail) }
      rendered.unshift(details_block(UsageDetails.new(@content['usage']).detail)) if @require_tables
      rendered
    end

    # The note is optional because it disappears once GitHub confirms the outcome.
    def wip
      spec = @content['wip']
      spec.nil? ? [] : [details_block(WipDetails.new(spec).detail)]
    end

    # Hand-written notes are what made each host publish a different shape.
    def refuse_free_form_usage(items)
      return unless items.any? { |item| item.is_a?(Hash) && UsageDetails.usage_summary?(item['summary']) }

      raise Error, 'Publication usage must be supplied as the usage object, not a details item.'
    end

    def refuse_free_form_wip(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(WipDetails::SUMMARY) }

      raise Error, 'Publication WIP Details must be supplied as the wip object, not a details item.'
    end

    def provenance
      spec = @content.fetch('provenance') do
        raise Error, 'Publication description requires execution provenance.'
      end
      [details_block(ExecutionProvenance.new(spec).detail)]
    end

    def details_block(detail)
      summary = PublicationText.summary_text(detail['summary'], 'details summary')
      body = PublicationText.required(detail['body'], "details #{summary}")
      summary = PublicationText.usage_cost_summary(summary, body)
      "<details>\n<summary>#{summary}</summary>\n\n#{body}\n\n</details>"
    end

    def revision
      head = @content['head']
      raise Error, 'Walkthrough requires the full commit SHA it explains.' unless head.to_s.match?(/\A[0-9a-f]{40}\z/)

      ["_Walkthrough for commit `#{head}`. This is a COMMENT, not an approval._"]
    end
  end
end
