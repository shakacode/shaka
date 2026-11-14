# frozen_string_literal: true

require 'date'
require 'json'
require 'open3'
require 'optparse'
require_relative 'error'
require_relative 'timings_report/aggregate'
require_relative 'timings_report/markdown'
require_relative 'timings_report/pull_row'

module Shaka
  # Adds up the timings that merged pull requests carry in their descriptions, so a retrospective can
  # rank where delivery time goes across many pull requests and see whether it shrinks week by week.
  module TimingsReport
    OPERATIONS = %w[report].freeze
    USAGE = 'Usage: shaka timings report --repository OWNER/REPO --since YYYY-MM-DD [--until YYYY-MM-DD] ' \
            '[--limit N] [--format markdown|json]'
    FIELDS = 'number,url,createdAt,mergedAt,isCrossRepository,body'

    module_function

    def run(arguments, fetch: method(:fetch))
      options = parse(arguments.dup)
      puts options[:help] || render(options, fetch.call(options))
      0
    rescue Error, OptionParser::ParseError, ArgumentError, SystemCallError, JSON::ParserError => e
      warn "shaka timings: #{e.message}"
      1
    end

    def render(options, pulls)
      report = Aggregate.call(pulls.filter_map { |pull| PullRow.call(pull) }, pulls.size, options)
      options[:format] == 'json' ? JSON.pretty_generate(report) : Markdown.call(report)
    end

    def parse(arguments)
      raise Error, USAGE unless OPERATIONS.include?(arguments.shift)

      options = { limit: 200, format: 'markdown' }
      parser(options).parse!(arguments)
      return options if options[:help]
      raise Error, USAGE unless options[:repository].to_s.match?(%r{\A[\w.-]+/[\w.-]+\z}) && options[:since]

      options
    end

    def parser(options)
      OptionParser.new(USAGE) do |parser|
        parser.on('-h', '--help', 'Show usage') { options[:help] = parser.to_s }
        parser.on('--repository REPO') { |value| options[:repository] = value }
        dates(parser, options)
        parser.on('--limit N', Integer) { |value| options[:limit] = value }
        parser.on('--format FORMAT', %w[markdown json]) { |value| options[:format] = value }
      end
    end

    def dates(parser, options)
      %i[since until].each { |key| parser.on("--#{key} DATE") { |value| options[key] = Date.iso8601(value) } }
    end

    def fetch(options)
      search = "merged:#{options[:since]}..#{options[:until] || '*'}"
      output, error, status = Open3.capture3('gh', 'pr', 'list', '--repo', options[:repository], '--state', 'merged',
                                             '--search', search, '--limit', options[:limit].to_s, '--json', FIELDS)
      raise Error, "gh pr list failed: #{error.strip}" unless status.success?

      JSON.parse(output)
    end
  end
end
