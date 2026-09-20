# frozen_string_literal: true

require_relative 'error'
require_relative 'provenance'

module Shaka
  # Checks supplied text for the mechanical failures models reproduce by hand.
  module PublicationText
    ESCAPE = /\\[nrt]/
    IDENTITY_FIELDS = %w[agent provider model effort].freeze

    module_function

    def required(value, field)
      raise Error, "Publication #{field} must be nonempty text." unless value.is_a?(String) && !value.strip.empty?

      checked(value, field)
    end

    # Fenced blocks and code spans hold intentional examples; only prose is checked.
    def prose(text)
      text.gsub(/^~~~.*?^~~~/m, '').gsub(/```.*?```/m, '').gsub(/(`+)(?:(?!\1).)*\1(?!`)/m, '')
    end

    # A summary is interpolated into raw HTML, so it must not be able to close its own tag.
    def summary_text(value, field)
      single_line(value, field).gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def list(value, field)
      return [] if value.nil?
      raise Error, "Publication #{field} must be a list." unless value.is_a?(Array)

      value
    end

    def single_line(value, field)
      text = required(value, field)
      raise Error, "Publication #{field} must be a single line." if text.match?(/[\r\n]/)

      text
    end

    def checked(value, field)
      return value unless prose(value).match?(ESCAPE)

      raise Error, "Publication #{field} contains a literal escape sequence; supply real line breaks."
    end

    def identity(value)
      raise Error, 'Publication identity must be supplied.' unless value.is_a?(Hash)

      fields = IDENTITY_FIELDS.map do |field|
        text = value[field]
        text.is_a?(String) && !text.strip.empty? ? single_line(text.strip, "identity #{field}") : 'UNKNOWN'
      end
      "🤖 #{fields.join(' · ')}"
    end
  end

  # Renders the publication surfaces so headings, spacing, tables and details are Ruby's.
  class Publication
    TABLE_SEPARATOR = /\A\s*\|[\s|:-]*-{3}[\s|:-]*\|\s*\z/
    WALKTHROUGH_URL = %r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/\d+#pullrequestreview-\d+\z}

    def self.description(content)
      new(content, require_tables: true).render(%i[walkthrough_ref sections table provenance details])
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

    def sections
      PublicationText.list(@content['sections'], 'sections').map do |section|
        heading = PublicationText.single_line(section['heading'], 'section heading')
        "## #{heading}\n\n#{PublicationText.required(section['body'], "section #{heading}")}"
      end
    end

    def walkthrough_ref
      url = PublicationText.single_line(walkthrough_url, 'walkthrough')
      unless url.match?(WALKTHROUGH_URL)
        raise Error, 'Publication walkthrough must be a GitHub pull request review URL.'
      end

      ["## Code Walkthrough\n\n[Code Walkthrough](#{url})"]
    end

    def walkthrough_url
      url = @content['walkthrough']
      return url if url.is_a?(String) && !url.strip.empty?

      raise Error, 'Publication description requires a walkthrough link.'
    end

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
      rendered = items.map { |detail| details_block(detail) }
      require_usage_table(items) if @require_tables
      rendered
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
      "<details>\n<summary>#{summary}</summary>\n\n#{body}\n\n</details>"
    end

    def require_usage_table(items)
      bodies = items.filter_map do |item|
        item['body'] if item.is_a?(Hash) && item['summary'].to_s.match?(/usage/i)
      end
      return if bodies.any? { |body| complete_markdown_table?(body) }

      raise Error, 'Publication description requires usage details with a table.'
    end

    def complete_markdown_table?(body)
      return false unless body.is_a?(String)

      PublicationText.prose(body).lines.map(&:rstrip).each_cons(3).any? do |header, separator, data|
        pipe_row?(header) && separator.match?(TABLE_SEPARATOR) && pipe_row?(data) && !data.match?(TABLE_SEPARATOR)
      end
    end

    def pipe_row?(line) = line.match?(/\A\s*\|.+\|\s*\z/)

    def revision
      head = @content['head']
      raise Error, 'Walkthrough requires the full commit SHA it explains.' unless head.to_s.match?(/\A[0-9a-f]{40}\z/)

      ["_Walkthrough for commit `#{head}`. This is a COMMENT, not an approval._"]
    end
  end
end
