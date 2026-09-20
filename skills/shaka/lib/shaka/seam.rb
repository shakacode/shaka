# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'repository_config'
require_relative 'seam/initializer'
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
      parser = option_parser
      parser.parse!(@arguments)
      return help(parser) if @options[:help]

      operation = @arguments.shift
      validate_operation(operation, parser)
      render_config(operation)
    end

    private

    def validate_operation(operation, parser)
      valid = %w[check init].include?(operation) && @arguments.empty?
      raise OptionParser::InvalidArgument, parser.to_s unless valid

      if operation == 'check'
        init_keys = %i[base_branch setup_command validate_command test_command review_policy review_check
                       merge_preference plan]
        raise OptionParser::InvalidArgument, 'init options do not apply to check' if @options.keys.intersect?(init_keys)
      elsif @options.key?(:ref)
        raise OptionParser::InvalidArgument, '--ref does not apply to init'
      end
    end

    def render_config(operation)
      config = operation == 'init' ? Initializer.new(root:, options: @options).call : checked_config
      puts JSON.pretty_generate(config.to_h)
      0
    end

    def checked_config
      TrustedConfigSource.load(root:, ref: @options[:ref])
    end

    def option_parser
      OptionParser.new do |flags|
        flags.banner = usage
        add_common_options(flags)
        add_init_options(flags)
        flags.on('-h', '--help', 'Show usage') { @options[:help] = true }
      end
    end

    def usage
      "Usage: shaka seam check [--root DIR] [--ref REF]\n       " \
        'shaka seam init --root DIR [options]'
    end

    def add_common_options(flags)
      flags.on('--root DIR', 'Repository root (default: current directory)') { |value| @options[:root] = value }
      flags.on('--ref REF', 'Read policy from this trusted Git commit') { |value| @options[:ref] = value }
    end

    def add_init_options(flags)
      flags.on('--base-branch BRANCH', 'Base branch when it is not the default branch') do |value|
        @options[:base_branch] = value
      end
      add_command_options(flags)
      add_policy_options(flags)
    end

    def add_command_options(flags)
      %w[setup validate test].each do |name|
        flags.on("--#{name}-command COMMAND", "Simple argv command for #{name}") do |value|
          @options[:"#{name}_command"] = value
        end
      end
    end

    def add_policy_options(flags)
      flags.on('--review-policy MODE', %w[always meaningful_changes none],
               'always, meaningful_changes, or none') { |value| @options[:review_policy] = value }
      flags.on('--review-check NAME', 'Independent review check name') { |value| @options[:review_check] = value }
      flags.on('--merge-preference MODE', %w[ask auto], 'ask or auto (default: ask)') do |value|
        @options[:merge_preference] = value
      end
      flags.on('--plan PATH', 'Optional repository-relative plan path') { |value| @options[:plan] = value }
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
