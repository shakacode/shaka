# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'call_log'
require_relative 'error'
require_relative 'help/catalog'
require_relative 'help/formatter'

module Shaka
  # Prints human-oriented help topics, example prompts, guide paths, and CLI command pointers.
  class Help
    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments, catalog: Catalog.load)
      @arguments = arguments.dup
      @catalog = catalog
      @options = {}
    end

    def run
      parser = option_parser
      parser.parse!(@arguments)
      return print_text(parser) if @options[:help]
      return run_json if @options[:json]
      return print_text(Formatter.overview(@catalog)) if @arguments.empty?

      dispatch(@arguments, parser)
    end

    private

    def option_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka help [TOPIC | COMMAND] [--json]'
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

      topic = @catalog.find(@arguments.first)
      raise Shaka::Error, unknown_message(@arguments) unless topic

      print_text(JSON.pretty_generate(topic))
    end

    def dispatch(args, parser)
      if args.length == 1
        topic = @catalog.find(args.first)
        return print_text(Formatter.topic(topic)) if topic
        return print_text(parser) if args.first == 'help'
      end

      pointer = command_pointer(args)
      return print_text(pointer) if pointer

      raise Shaka::Error, unknown_message(args)
    end

    def command_pointer(args)
      name, operation = args
      return unless CallLog::COMMANDS.include?(name)

      operations = CallLog::OPERATIONS.fetch(name, [])
      return unless args.length == 1 || (args.length == 2 && operations.include?(operation))

      Formatter.command_pointer(name, operation:, operations:)
    end

    def unknown_message(args)
      "unknown help topic or command: #{args.join(' ')}. Run `shaka help` to list topics."
    end
  end
end
