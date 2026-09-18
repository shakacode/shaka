# frozen_string_literal: true

require 'open3'
require 'optparse'
require_relative 'error'
require_relative 'usage'
require_relative 'doctor/checks'

module Shaka
  # Reports whether this machine can run the workflow and publish a complete pull request.
  # Read-only: it inspects the environment and changes no repository and no setting.
  class Doctor
    SEVERITY = { 'healthy' => 0, 'skipped' => 0, 'degraded' => 1, 'failed' => 2 }.freeze
    RUNNER = ->(argv) { Open3.capture3(*argv).then { |out, err, status| [out, err, status.success?] } }

    def self.run(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return help(parser) if options[:help]

      report(arguments, options, parser)
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def self.report(arguments, options, parser)
      raise OptionParser::InvalidArgument, parser.to_s unless arguments.empty?

      subject = new(root: File.realpath(options.fetch(:root, Dir.pwd)))
      puts subject.report
      subject.blocked? ? 1 : 0
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka doctor [--root DIR]'
        flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
        flags.on('-h', '--help', 'Show usage') { options[:help] = true }
      end
    end

    def self.help(parser)
      puts parser
      0
    end

    private_class_method :report, :option_parser, :help

    def initialize(root:, environment: ENV, runner: RUNNER, usage_source: nil)
      @root = root
      @host = Usage.detected_host
      @source = Checks.new(root: root, host: @host, environment: environment, runner: runner,
                           usage_source: usage_source || ->(host) { Usage::READERS.fetch(host).discover })
    end

    def checks = @checks ||= @source.call

    def blocked? = checks.any? { |item| item.fetch(:status) == 'failed' }

    def report
      ["Shaka doctor: #{overall.upcase}", context, '', *ordered.map { |item| render(item) }].join("\n")
    end

    private

    # Worst first, and stable within a status so the check order stays predictable.
    def ordered = checks.sort_by.with_index { |item, index| [-SEVERITY.fetch(item.fetch(:status)), index] }

    def overall = checks.map { |item| item.fetch(:status) }.max_by { |status| SEVERITY.fetch(status) } || 'healthy'

    def context = "Ruby #{RUBY_VERSION} · host #{@host} · root #{@root}"

    def render(item)
      lines = ["[#{item.fetch(:status).upcase}] #{item.fetch(:name)} — #{item.fetch(:summary)}"]
      lines << "    Next: #{item[:guidance]}" if item[:guidance]
      lines.join("\n")
    end
  end
end
