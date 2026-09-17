# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'repository_config'
require_relative 'trusted_config_source'

module Shaka
  # Validates the machine-readable repository boundary.
  class Seam
    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments)
      @arguments = arguments.dup
      @options = {}
    end

    def run
      operation = @arguments.shift
      parser = option_parser
      parser.parse!(@arguments)
      return help(parser) if @options[:help]

      validate_operation(operation, parser)
      render_config
    end

    private

    def validate_operation(operation, parser)
      return if operation == 'check' && @arguments.empty?

      raise OptionParser::InvalidArgument, parser.to_s
    end

    def render_config
      source = TrustedConfigSource.new(root:).read(@options[:ref]) if @options[:ref]
      puts JSON.pretty_generate(RepositoryConfig.load(root:, source:).to_h)
      0
    end

    def option_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka seam check [--root DIR] [--ref REF]'
        flags.on('--root DIR', 'Repository root (default: current directory)') { |value| @options[:root] = value }
        flags.on('--ref REF', 'Read policy from this trusted Git commit') { |value| @options[:ref] = value }
        flags.on('-h', '--help', 'Show usage') { @options[:help] = true }
      end
    end

    def help(parser)
      puts parser
      0
    end

    def root
      File.realpath(@options.fetch(:root, Dir.pwd))
    end
  end
end
