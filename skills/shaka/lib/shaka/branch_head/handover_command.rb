# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../branch_head'
require_relative '../doctor/bounded_command'
require_relative '../error'
require_relative '../local_review/path_guard'
require_relative 'handover'
require_relative 'owner_tag'
require_relative 'ownership'

module Shaka
  class BranchHead
    # Parses `shaka handover release|pickup|status --pr OWNER/REPO#NUMBER` and prints the result. Ownership lives on
    # the PR, so these commands name it; `shaka branch` stays about origin's same-named branch. A state in which this
    # checkout must not work on the PR exits 2.
    module HandoverCommand
      OPERATIONS = %w[release pickup status].freeze
      CONTINUE = %w[holds picked_up].freeze
      PR = %r{\A(?<repository>[\w.-]+/[\w.-]+)#(?<number>\d+)\z}
      FIELDS = 'state,headRefName,headRefOid,statusCheckRollup,body,author'
      SECONDS = 30
      HOLDS = 'This checkout holds the PR. Continue.'
      AUTHORITY = { 'release' => ['--maintainer', 'Release for an owner who cannot (maintain or admin role)'],
                    'pickup' => ['--override', 'Take over an unreleased PR a maintainer confirmed abandoned'] }.freeze

      module_function

      def run(arguments)
        operation = arguments.shift
        options = parse(operation, arguments)
        return 0 unless options

        result = outcome(operation, options)
        puts JSON.pretty_generate(result)
        CONTINUE.include?(result['state']) ? 0 : 2
      rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
        warn "shaka: #{BranchHead.redact(e.message)}"
        1
      end

      def outcome(operation, options)
        cli = gh_runtime(options[:root])
        pull = pull_request(options[:pr], cli)
        raise Error, "The PR is #{pull['state'].to_s.downcase}; nothing to hand over." unless pull['state'] == 'OPEN'

        ownership = Ownership.new(options[:pr], pull['author'], cli)
        return status(options[:root], ownership) if operation == 'status'

        hand_over(operation, ownership, pull, options)
      end

      def hand_over(operation, ownership, pull, options)
        root = options[:root]
        handover = Handover.new(BranchHead.new(root:), ownership, content(options), root)
        return handover.release(pull, maintainer: options[:maintainer]) if operation == 'release'

        handover.pickup(pull, override: options[:override])
      end

      # Whether this checkout still holds the PR, as every turn's check asks once the task has one.
      def status(root, ownership)
        state = ownership.state
        paused = Ownership.pause(state, OwnerTag.recorded(root))
        return { 'state' => 'holds', 'owner' => state['owner'], 'guidance' => HOLDS }.compact unless paused

        { 'state' => paused, 'owner' => state['owner'], 'decided_by' => state['url'],
          'guidance' => Ownership::GUIDANCE.fetch(paused) }.compact
      end

      def content(options)
        path = options.fetch(:content_file) { raise Error, 'Pass --content-file PATH.' }
        content = JSON.parse(File.read(path, encoding: 'UTF-8'))
        raise Error, 'The content file must hold a JSON object.' unless content.is_a?(Hash)

        content
      rescue JSON::ParserError => e
        raise Error, "Cannot parse the content file: #{e.message}"
      end

      def pull_request(request, cli)
        argv = [*cli, 'pr', 'view', request[:number], '--repo', request[:repository], '--json', FIELDS]
        output, error, success = Doctor::BoundedCommand.new(timeout: SECONDS).call(argv)
        raise Error, "Cannot read PR #{request}: #{error.strip}" unless success

        pull = JSON.parse(output)
        { 'state' => pull['state'], 'branch' => pull['headRefName'], 'head' => pull['headRefOid'],
          'checks' => pull['statusCheckRollup'], 'body' => pull['body'], 'author' => pull.dig('author', 'login') }
      rescue JSON::ParserError => e
        raise Error, "Cannot parse PR #{request}: #{e.message}"
      end

      # A PATH without the checkout's directories and a gh from it, so a gh committed in the checkout never runs.
      def gh_runtime(root)
        checkout = File.realpath(root)
        path = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: checkout, drop_candidate: true)
        gh = LocalReviewPathGuard.safe_executable(path, 'gh', checkout)
        raise Error, 'gh is not on PATH outside the checkout' unless gh

        [{ 'PATH' => path }, gh]
      end

      def parse(operation, arguments)
        unless OPERATIONS.include?(operation)
          raise OptionParser::InvalidArgument, "Usage: shaka handover #{OPERATIONS.join('|')}"
        end

        options = { root: Dir.pwd }
        parser = option_parser(operation, options)
        parser.parse!(arguments)
        return puts(parser) if options[:help]
        raise OptionParser::InvalidArgument, parser.to_s unless arguments.empty? && options[:pr]

        options.merge(root: File.realpath(options[:root]))
      end

      def option_parser(operation, options)
        OptionParser.new do |flags|
          flags.banner = "Usage: shaka handover #{operation} --pr OWNER/REPO#NUMBER [--root DIR]"
          flags.on('--root DIR', 'Checkout with the PR branch checked out') { |value| options[:root] = value }
          flags.on('--pr OWNER/REPO#NUMBER', 'The unfinished PR') do |value|
            options[:pr] = PR.match(value) || raise(OptionParser::InvalidArgument, '--pr needs OWNER/REPO#NUMBER')
          end
          authority_flags(operation, flags, options)
          flags.on('-h', '--help', 'Show usage') { options[:help] = true }
        end
      end

      def authority_flags(operation, flags, options)
        return if operation == 'status'

        flags.on('--content-file PATH', 'JSON with identity, owner_tag, and for a release remaining') do |value|
          options[:content_file] = value
        end
        flag, text = AUTHORITY.fetch(operation)
        flags.on(flag, text) { options[flag.delete_prefix('--').to_sym] = true }
      end

      private_class_method :outcome, :hand_over, :content, :pull_request, :gh_runtime, :parse, :option_parser,
                           :authority_flags
    end
  end
end
