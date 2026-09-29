# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'private_setup'

module Shaka
  class Seam
    # Parses local-only setup and recovery commands independently of trusted policy.
    class PrivateCommand
      OPERATIONS = %w[setup inspect list restore].freeze

      def self.run(arguments)
        new(arguments).run
      end

      def initialize(arguments)
        @arguments = arguments.dup
        @options = {}
      end

      def run
        operation = @arguments.shift
        parser = option_parser
        parser.parse!(@arguments)
        raise OptionParser::InvalidArgument, parser.to_s unless @arguments.empty? && OPERATIONS.include?(operation)

        root = File.realpath(@options.fetch(:root, Dir.pwd))
        output = execute(operation, root)
        puts JSON.pretty_generate(output)
        0
      end

      private

      def execute(operation, root)
        return setup(root) if operation == 'setup'

        recovery = PrivateRecovery.new(root:)
        return recovery.inspect_checkout if operation == 'inspect'
        return recovery.list if operation == 'list'

        raise Error, '--to is required for private restore' unless @options[:to]

        recovery.restore(to: @options[:to], id: @options[:id], previous: @options.fetch(:previous, false))
      end

      def setup(root)
        raise Error, '--ref is required for private setup' unless @options[:ref]

        PrivateSetup.new(root:, ref: @options[:ref], options: @options).setup
      end

      def option_parser
        OptionParser.new do |flags|
          flags.banner = 'Usage: shaka seam private setup|inspect|list|restore --root DIR [options]'
          add_setup_options(flags)
          flags.on('--root DIR') { |value| @options[:root] = value }
          flags.on('--id ID') { |value| @options[:id] = value }
          flags.on('--to PATH') { |value| @options[:to] = value }
          flags.on('--previous') { @options[:previous] = true }
        end
      end

      def add_setup_options(flags)
        flags.on('--ref SHA') { |value| @options[:ref] = value }
        add_command_options(flags)
        add_review_options(flags)
        flags.on('--base-branch BRANCH') { |value| @options[:base_branch] = value }
      end

      def add_command_options(flags)
        %w[setup validate test].each do |name|
          flags.on("--#{name}-command COMMAND") { |value| @options[:"#{name}_command"] = value }
        end
        %w[validate-local trigger-hosted-ci].each do |name|
          flags.on("--#{name}-command COMMAND") { |value| @options[:"#{name.tr('-', '_')}_command"] = value }
        end
      end

      def add_review_options(flags)
        flags.on('--review-policy MODE', %w[always meaningful_changes none]) do |value|
          @options[:review_policy] = value
        end
        flags.on('--ci-review-job NAME') { |value| (@options[:ci_review_jobs] ||= []) << value }
      end
    end
  end
end
