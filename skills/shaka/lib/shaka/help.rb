# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'help/catalog'
require_relative 'help/formatter'

module Shaka
  # Prints human-oriented help topics, example prompts, and guide locations.
  class Help
    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments, catalog: nil)
      @arguments = arguments.dup
      @catalog = catalog
      @options = {}
    end

    def run
      parser = option_parser
      parser.permute!(@arguments)
      return print_text(parser) if @options[:help]

      @catalog ||= Catalog.load
      return run_json if @options[:json]
      return print_text(Formatter.overview(@catalog)) if @arguments.empty?

      dispatch(@arguments, parser)
    end

    private

    def option_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka help [TOPIC] [--json]'
        flags.on('--json', 'Print topics or one topic as JSON') { @options[:json] = true }
        flags.on('-h', '--help', 'Show usage') { @options[:help] = true }
      end
    end

    def print_text(text)
      puts text
      0
    end

    def run_json
      return print_text(JSON.pretty_generate(@catalog.to_h)) if @arguments.empty?
      raise Shaka::Error, 'shaka help --json accepts at most one topic name.' if @arguments.length > 1

      print_text(JSON.pretty_generate(find_topic!(@arguments)))
    end

    def dispatch(args, parser)
      return print_text(parser) if args == ['help']
      raise Shaka::Error, unknown_message(args) if args.length > 1

      print_text(Formatter.topic(find_topic!(args)))
    end

    def find_topic!(args)
      @catalog.find(args.first) || raise(Shaka::Error, unknown_message(args))
    end

    def unknown_message(args)
      "unknown help topic: #{args.join(' ')}. Run `shaka help` for topics or `shaka --help` for CLI commands."
    end
  end
end
