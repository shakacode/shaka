# frozen_string_literal: true

require 'optparse'
require_relative '../error'

module Shaka
  class Snapshot
    # Reads the command line for one snapshot.
    class Options
      def self.parse(arguments) = new(arguments).parse

      def initialize(arguments)
        @arguments = arguments.dup
        @options = { remote: 'origin' }
      end

      def parse
        parser = option_parser
        parser.parse!(@arguments)
        raise OptionParser::InvalidArgument, parser.to_s unless @arguments.empty?

        @options
      end

      private

      def option_parser
        OptionParser.new do |flags|
          flags.banner = 'Usage: shaka snapshot [--push] [--remote NAME] [--delete]'
          flags.on('--push', 'Publish the snapshot; without it the plan is printed only') { @options[:push] = true }
          flags.on('--expect DIGEST', 'The digest the plan printed; required with --push') { |v| @options[:expect] = v }
          flags.on('--remote NAME', 'Remote to publish to; default origin') { |name| @options[:remote] = remote!(name) }
          flags.on('--delete', 'Delete this branch snapshot instead of publishing one') { @options[:delete] = true }
        end
      end

      # Git reads a leading dash as an option, and `--upload-pack` names a program to run.
      def remote!(name)
        raise Error, "A remote cannot begin with a dash: #{name}" if name.start_with?('-')

        name
      end
    end
  end
end
