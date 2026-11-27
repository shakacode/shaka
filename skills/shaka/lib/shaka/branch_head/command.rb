# frozen_string_literal: true

require 'json'
require 'open3'
require 'uri'
require 'optparse'
require_relative '../branch_head'
require_relative '../doctor/bounded_command'
require_relative '../error'
require_relative '../git_origin'

module Shaka
  class BranchHead
    # Parses `shaka branch check|accept|push` and prints the result; a state that pauses work exits 2.
    module Command
      OPERATIONS = %w[check accept push].freeze
      PAUSE_EXIT = 2
      PR_SECONDS = 30
      PR = %r{\A(?<repository>[\w.-]+/[\w.-]+)#(?<number>\d+)\z}

      module_function

      def run(arguments)
        operation = arguments.shift
        options = parse(operation, arguments)
        return 0 unless options

        result = outcome(operation, options)
        puts JSON.pretty_generate(result)
        BranchHead::SAFE.include?(result['state']) ? 0 : PAUSE_EXIT
      rescue OptionParser::ParseError, SystemCallError, Shaka::Error, URI::Error, JSON::ParserError, KeyError => e
        warn "shaka: #{BranchHead.redact(e.message)}"
        1
      end

      def outcome(operation, options)
        pull = (pr_head(options[:root], options[:pr]) if options[:pr])
        perform(operation, BranchHead.new(root: options[:root], pr_head: pull), options)
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
          flags.banner = "Usage: shaka branch #{operation} [--root DIR] [--pr OWNER/REPO#NUMBER]"
          flags.on('--root DIR', 'Checkout with the task branch checked out') { |value| options[:root] = value }
          flags.on('--pr OWNER/REPO#NUMBER', 'PR whose head origin must hold') do |value|
            options[:pr] =
              PR.match(value) || raise(OptionParser::InvalidArgument, "--pr needs OWNER/REPO#NUMBER, not #{value}")
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

      # The named PR's state, head repository, and branch. The repository and origin's push host are explicit, so
      # gh cannot pick another repository or host.
      def pr_head(root, request)
        fields = 'url,state,headRefName,headRepository,headRepositoryOwner'
        repository = "#{push_host(root)}/#{request[:repository]}"
        argv = ['gh', 'pr', 'view', request[:number], '--repo', repository, '--json', fields]
        output, error, success = Doctor::BoundedCommand.new(timeout: PR_SECONDS).call(argv, root)
        raise Error, "Cannot read PR #{request}: #{error.strip}" unless success

        head_of(JSON.parse(output), request[:number])
      end

      # The host origin pushes to, which may differ from the host it fetches from.
      def push_host(root)
        url, error, status = Open3.capture3(Destination::ENVIRONMENT, 'git', '-C', root, 'remote', 'get-url', '--push',
                                            'origin')
        raise Error, "Cannot read origin's push URL: #{error.strip}" unless status.success?

        URI(GitOrigin.canonical_url(url.strip)).host
      end

      # Only an open PR has a head to check; once it merges or closes, the workflow stops running the check.
      # A deleted fork leaves no head repository, so there is no destination to match.
      def head_of(pull, number)
        unless pull['state'] == 'OPEN'
          raise Error,
                "PR ##{number} is #{pull['state'].to_s.downcase}; stop running branch commands for it."
        end

        owner = pull.dig('headRepositoryOwner', 'login')
        name = pull.dig('headRepository', 'name')
        raise Error, "PR ##{number} has no head repository." unless owner && name

        { 'url' => "https://#{URI(pull.fetch('url')).host}/#{owner}/#{name}", 'branch' => pull['headRefName'] }
      end

      private_class_method :outcome, :pr_head, :push_host, :head_of, :perform, :parse, :option_parser,
                           :operation_flags,
                           :accept_flags
    end
  end
end
