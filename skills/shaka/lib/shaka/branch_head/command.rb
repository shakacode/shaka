# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../branch_head'
require_relative '../error'

module Shaka
  class BranchHead
    # Parses `shaka branch check|accept` and prints the result; a state that pauses work exits 2.
    module Command
      OPERATIONS = %w[check accept].freeze
      PAUSE_EXIT = 2

      module_function

      def run(arguments)
        operation = arguments.shift
        options = parse(operation, arguments)
        return 0 unless options

        head = BranchHead.new(**options.slice(:root, :remote, :branch))
        result = operation == 'check' ? head.check : head.accept(options[:head], absent: options[:absent])
        puts JSON.pretty_generate(result)
        BranchHead::SAFE.include?(result['state']) || operation == 'accept' ? 0 : PAUSE_EXIT
      rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
        warn "shaka: #{e.message}"
        1
      end

      def parse(operation, arguments)
        unless OPERATIONS.include?(operation)
          raise OptionParser::InvalidArgument,
                "Usage: shaka branch #{OPERATIONS.join('|')}"
        end

        options = { root: Dir.pwd, remote: 'origin' }
        parser = option_parser(operation, options)
        parser.parse!(arguments)
        return puts(parser) if options[:help]
        raise OptionParser::InvalidArgument, parser.to_s unless arguments.empty?

        options.merge(root: File.realpath(options[:root]))
      end

      def option_parser(operation, options)
        OptionParser.new do |flags|
          flags.banner = "Usage: shaka branch #{operation} [--root DIR] [--remote NAME] [--branch NAME]"
          flags.on('--root DIR', 'Checkout holding the task branch') { |value| options[:root] = value }
          flags.on('--remote NAME', 'Remote holding the branch (default: origin)') { |value| options[:remote] = value }
          flags.on('--branch NAME', 'Task branch (default: the checked-out branch)') do |value|
            options[:branch] = value
          end
          accept_flags(flags, options) if operation == 'accept'
          flags.on('-h', '--help', 'Show usage') { options[:help] = true }
        end
      end

      def accept_flags(flags, options)
        flags.banner += ' (--head SHA | --absent)'
        flags.on('--head SHA', 'Live remote head to accept') { |value| options[:head] = value }
        flags.on('--absent', 'Accept that the branch is not on the remote') { options[:absent] = true }
      end

      private_class_method :parse, :option_parser, :accept_flags
    end
  end
end
