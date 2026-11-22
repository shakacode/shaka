# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'help/catalog'
require_relative 'help/formatter'

module Shaka
  # Prints human-oriented help topics, example prompts, guide paths, and CLI command usage.
  class Help
    PR_COMMANDS = %w[pr comments description reply start resolve walkthrough merge attention
                     squash-message handoff].freeze

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
      parser.order!(@arguments)
      return print_text(parser) if @options[:help]
      return run_json if @options[:json]
      return print_text(Formatter.overview(@catalog)) if @arguments.empty?

      dispatch(@arguments, parser)
    end

    private

    def option_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka help [TOPIC | COMMAND [OPERATION]] [--json]'
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
      if args.length == 1 && (topic = @catalog.find(args.first))
        return print_text(Formatter.topic(topic))
      end

      status = forward_command(strip_trailing_help(args), parser)
      return status unless status.nil?

      raise Shaka::Error, unknown_message(args)
    end

    def strip_trailing_help(args)
      args.length > 1 && %w[-h --help].include?(args.last) ? args[0...-1] : args
    end

    def forward_command(args, parser)
      return print_text(parser) if args == ['help']
      return forward_pr_watch if args == %w[pr watch]

      name, *rest = args
      return forward_subcommand(name, rest) if Subcommands::TABLE.key?(name)

      print_text(Formatter.pr_command(name)) if rest.empty? && PR_COMMANDS.include?(name)
    end

    def forward_pr_watch
      require_relative 'pr_watch/command'
      PrWatch::Command.run(['--help'])
    end

    def forward_subcommand(name, rest)
      entry = Subcommands::TABLE.fetch(name)
      return unless rest.empty? || (rest.length == 1 && entry.operations.include?(rest.first))

      status = entry.run.call([*rest, '--help'])
      status.is_a?(Integer) ? status : 0
    rescue SystemExit => e
      e.status
    end

    def unknown_message(args)
      "unknown help topic or command: #{args.join(' ')}. Run `shaka help` to list topics."
    end
  end
end
