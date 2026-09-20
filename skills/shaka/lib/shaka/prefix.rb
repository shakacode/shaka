# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'git_origin'
require_relative 'repo_prefix'
require_relative 'trusted_config_source'

module Shaka
  # Prints the display prefix for one repository from its trusted seam.
  class Prefix
    def self.run(arguments)
      options = parse(arguments)
      return 0 unless options

      puts JSON.pretty_generate(new(root: options[:root], ref: options[:ref]).call)
      0
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def self.parse(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return help(parser) if options[:help]
      raise OptionParser::InvalidArgument, parser.to_s unless arguments.empty?

      { root: File.realpath(options.fetch(:root, Dir.pwd)), ref: options[:ref] }
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka prefix [--root DIR] [--ref REF]'
        flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
        flags.on('--ref REF', 'Trusted Git commit or ref (default: origin/HEAD)') { |value| options[:ref] = value }
        flags.on('-h', '--help', 'Show usage') { options[:help] = true }
      end
    end

    def self.help(parser)
      puts parser
      nil
    end

    private_class_method :parse, :option_parser, :help

    def initialize(root:, ref: nil)
      @root = root
      @ref = ref
    end

    def call
      config = TrustedConfigSource.load(root: @root, ref: @ref || 'origin/HEAD').to_h
      RepoPrefix.display(configured: config['repo_prefix'], repository_name: GitOrigin.repository_name(root: @root))
    end
  end
end
