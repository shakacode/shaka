# frozen_string_literal: true

require 'json'
require 'open3'
require 'optparse'
require_relative 'error'
require_relative 'claim/names'
require_relative 'repository_config'

module Shaka
  # Lists open pull requests and remote branches that already cover a work item.
  class Claim
    PR_JSON = 'number,title,url,headRefName'

    def self.run(arguments, runner: nil)
      query, root = parse(arguments)
      return 0 unless query

      subject = new(query: query, root: root, runner: runner, branch_name: branch_name_for(root))
      puts JSON.generate(subject.result)
      0
    rescue OptionParser::ParseError, JSON::ParserError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def self.parse(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return help(parser) if options[:help]
      raise OptionParser::InvalidArgument, parser.to_s unless arguments.length == 1

      [arguments.first, File.realpath(options.fetch(:root, Dir.pwd))]
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka claim QUERY [--root DIR]'
        flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
        flags.on('-h', '--help', 'Show usage') { options[:help] = true }
      end
    end

    def self.help(parser)
      puts parser
      nil
    end

    def self.branch_name_for(root)
      RepositoryConfig.load(root: root).to_h.dig('branches', 'name')
    end

    private_class_method :parse, :option_parser, :help, :branch_name_for

    def initialize(query:, root:, runner: nil, branch_name: nil)
      @query = positive_integer(query).to_s
      @root = root
      @runner = runner || ->(argv, stdin_data: '') { Open3.capture3(*argv, stdin_data: stdin_data, chdir: @root) }
      @names = Names.new(query: @query, template: branch_name)
    end

    def result
      listed = listed_pull_requests
      matching = matching_branches
      {
        'query' => @query,
        'branch_name' => @names.reported,
        'pull_requests' => listed,
        'branches' => matching,
        'collision' => listed.any? || matching.any?
      }
    end

    private

    def listed_pull_requests
      parsed = JSON.parse(capture(['gh', 'pr', 'list', '--search', @query, '--state', 'open', '--json', PR_JSON]))
      raise Error, 'GitHub pull request list must be an array.' unless parsed.is_a?(Array)

      parsed
    rescue JSON::ParserError
      raise Error, 'GitHub returned invalid JSON.'
    end

    def matching_branches
      capture(['git', 'ls-remote', '--heads', 'origin']).each_line.filter_map do |line|
        name = line.split("\t", 2)[1]&.delete_prefix('refs/heads/')&.strip
        name if name && @names.cover?(name)
      end
    end

    def capture(argv)
      stdout, _stderr, status = @runner.call(argv, stdin_data: '')
      return utf8(stdout) if status.respond_to?(:exitstatus) && status.exitstatus.zero?

      code = status.respond_to?(:exitstatus) ? status.exitstatus : status
      raise Error, "#{argv.first} #{argv[1]} failed (exit #{code})."
    rescue Errno::ENOENT
      raise Error, "#{argv.first} is unavailable."
    end

    def positive_integer(value)
      unless value.to_s.ascii_only? && value.to_s.match?(/\A[1-9]\d*\z/)
        raise Error, 'Expected a positive integer identifier.'
      end

      value.to_i
    end

    def utf8(value)
      raise Error, 'Expected UTF-8 text.' unless value.is_a?(String)

      text = value.dup.force_encoding(Encoding::UTF_8)
      raise Error, 'Invalid UTF-8 text.' unless text.valid_encoding?

      text
    end
  end
end
