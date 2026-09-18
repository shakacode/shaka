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
    SEVERITY = { 'healthy' => 0, 'degraded' => 1, 'failed' => 2 }.freeze
    # No deadline: a stalled gh can still hang this command. Bounding it correctly needs real
    # process supervision, so it is tracked separately rather than faked here.
    RUNNER = ->(argv) { Open3.capture3(*argv).then { |out, err, status| [out, err, status.success?] } }

    # Everything doctor reaches outside its own process, in one place so a test can state
    # the machine it describes instead of inheriting the one it runs on.
    System = Struct.new(:runner, :usage_source, :host_name, keyword_init: true) do
      def self.default
        new(runner: RUNNER, usage_source: ->(name) { Usage::READERS.fetch(name).discover },
            host_name: MachineAlias.system_name)
      end
    end

    def self.run(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return help(parser) if options[:help]

      report(arguments, options)
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def self.report(arguments, options)
      raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?

      subject = new(root: File.realpath(options.fetch(:root, Dir.pwd)), host: options[:host])
      puts subject.report
      subject.blocked? ? 1 : 0
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka doctor [--root DIR]'
        flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
        flags.on('--host NAME', Usage::READERS.keys, 'codex, claude-code, cursor, or opencode') do |value|
          options[:host] = value
        end
        flags.on('-h', '--help', 'Show usage') { options[:help] = true }
      end
    end

    def self.help(parser)
      puts parser
      0
    end

    private_class_method :report, :option_parser, :help

    def initialize(root:, host: nil, environment: ENV, system: System.default)
      @root = root
      @stated = !host.nil?
      @host = host || Usage.detected_host
      @source = Checks.new(root: root, host: @host, environment: environment, system: system)
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

    # Detection falls back to codex when a host exposes no session identifier, so the report
    # says which host it assumed and `--host` states it instead.
    # Detection answers nil when several hosts are present and falls back to codex when none
    # is, so the report always says which host it used and how sure it is.
    def context = "Ruby #{RUBY_VERSION} · host #{named_host} · root #{@root}"

    def named_host
      return 'ambiguous' if @host.nil?

      @stated ? @host : "#{@host} (detected)"
    end

    def render(item)
      lines = ["[#{item.fetch(:status).upcase}] #{item.fetch(:name)} — #{item.fetch(:summary)}"]
      lines << "    Next: #{item[:guidance]}" if item[:guidance]
      lines.join("\n")
    end
  end
end
