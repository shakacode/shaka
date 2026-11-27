# frozen_string_literal: true

require 'json'
require 'open3'
require 'optparse'
require_relative '../branch_head'
require_relative '../error'

module Shaka
  class BranchHead
    # Parses `shaka branch check|accept|push` and prints the result; a state that pauses work exits 2.
    module Command
      OPERATIONS = %w[check accept push].freeze
      PAUSE_EXIT = 2

      module_function

      def run(arguments)
        operation = arguments.shift
        options = parse(operation, arguments)
        return 0 unless options

        head = BranchHead.new(root: options[:root], pr_head: (pr_head(options[:root], options[:pr]) if options[:pr]))
        result = perform(operation, head, options)
        puts JSON.pretty_generate(result)
        BranchHead::SAFE.include?(result['state']) ? 0 : PAUSE_EXIT
      rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
        warn "shaka: #{e.message}"
        1
      end

      def perform(operation, head, options)
        case operation
        when 'check' then head.check
        when 'accept' then head.accept(options[:head], absent: options[:absent])
        else head.push(rewrite: options[:rewrite])
        end
      end

      def parse(operation, arguments)
        unless OPERATIONS.include?(operation)
          raise OptionParser::InvalidArgument, "Usage: shaka branch #{OPERATIONS.join('|')}"
        end

        options = { root: Dir.pwd }
        parser = option_parser(operation, options)
        parser.parse!(arguments)
        return puts(parser) if options[:help]
        raise OptionParser::InvalidArgument, parser.to_s unless arguments.empty?

        options.merge(root: File.realpath(options[:root]))
      end

      def option_parser(operation, options)
        OptionParser.new do |flags|
          flags.banner = "Usage: shaka branch #{operation} [--root DIR] [--pr NUMBER]"
          flags.on('--root DIR', 'Checkout with the task branch checked out') { |value| options[:root] = value }
          flags.on('--pr NUMBER', Integer, 'PR whose head must be the push destination') do |value|
            options[:pr] = value
          end
          operation_flags(operation, flags, options)
          flags.on('-h', '--help', 'Show usage') { options[:help] = true }
        end
      end

      def operation_flags(operation, flags, options)
        accept_flags(flags, options) if operation == 'accept'
        return unless operation == 'push'

        flags.banner += ' [--rewrite]'
        flags.on('--rewrite', 'Allow replacing the accepted head, as an intended rebase does') do
          options[:rewrite] = true
        end
      end

      def accept_flags(flags, options)
        flags.banner += ' (--head SHA | --absent)'
        flags.on('--head SHA', 'Live remote head to accept') { |value| options[:head] = value }
        flags.on('--absent', 'Accept that the branch is not on the remote') { options[:absent] = true }
      end

      # The PR's head repository and branch, read with gh from the checkout's repository.
      def pr_head(root, number)
        output, error, status = Open3.capture3('gh', 'pr', 'view', number.to_s, '--json',
                                               'headRefName,headRepository,headRepositoryOwner', chdir: root)
        raise Error, "Cannot read PR ##{number}: #{error.strip}" unless status.success?

        pull = JSON.parse(output)
        { 'repository' => "#{pull.dig('headRepositoryOwner', 'login')}/#{pull.dig('headRepository', 'name')}",
          'branch' => pull['headRefName'] }
      end

      private_class_method :pr_head, :perform, :parse, :option_parser, :operation_flags, :accept_flags
    end
  end
end
