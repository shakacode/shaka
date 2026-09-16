# frozen_string_literal: true

require_relative 'error'

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
      text.gsub(/^~~~.*?^~~~/m, '').gsub(/```.*?```/m, '').gsub(/(`+)[^`]*\1/, '')
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
    def self.description(content) = new(content).render(%i[sections table details])
    def self.comment(content) = new(content).render([])
    def self.walkthrough(content) = new(content).render(%i[sections table details revision])

    def initialize(content)
      raise Error, 'Publication content must be an object.' unless content.is_a?(Hash)

      @content = content
    end

    def render(parts)
      blocks = [PublicationText.identity(@content['identity']),
                PublicationText.required(@content['summary'], 'summary')]
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

    def table
      spec = @content['table']
      return [] if spec.nil?

      columns = table_columns(spec)
      rows = PublicationText.list(spec['rows'], 'table rows').map { |row| table_row(row, columns.size) }
      [[table_line(columns), table_line(['---'] * columns.size), *rows].join("\n")]
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
      PublicationText.list(@content['details'], 'details').map do |detail|
        summary = PublicationText.summary_text(detail['summary'], 'details summary')
        body = PublicationText.required(detail['body'], "details #{summary}")
        "<details>\n<summary>#{summary}</summary>\n\n#{body}\n\n</details>"
      end
    end

    def revision
      head = @content['head']
      raise Error, 'Walkthrough requires the full commit SHA it explains.' unless head.to_s.match?(/\A[0-9a-f]{40}\z/)

      ["_Walkthrough for commit `#{head}`. This is a COMMENT, not an approval._"]
    end
  end
end
