# frozen_string_literal: true

require 'open3'
require 'optparse'
require 'json'
require_relative 'error'
require_relative 'version'
require_relative 'usage/usage'
require_relative 'doctor/bounded_command'
require_relative 'doctor/checks'
require_relative 'doctor/cursor_stop_hook'

module Shaka
  # Reports whether this machine can run the workflow and publish a complete pull request.
  # Read-only: it inspects the environment and changes no repository and no setting.
  class Doctor
    SEVERITY = { 'healthy' => 0, 'degraded' => 1, 'failed' => 2 }.freeze
    # Long enough that a slow network answer is not mistaken for a hang, short enough that a
    # stalled credential helper does not look like a working command.
    TIMEOUT = 15
    RUNNER = BoundedCommand.new(timeout: TIMEOUT)

    # Everything doctor reaches outside its own process, in one place so a test can state
    # the machine it describes instead of inheriting the one it runs on.
    System = Struct.new(:runner, :usage_source, :host_name, :ruby_version, :cursor_stop_hook,
                        keyword_init: true) do
      def self.default
        new(runner: RUNNER, usage_source: ->(name) { Usage::READERS.fetch(name).discover },
            host_name: MachineAlias.system_name, ruby_version: RUBY_VERSION,
            cursor_stop_hook: -> { CursorStopHook.installed? })
      end
    end

    def self.run(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return help(parser) if options[:help]

      return report_installation(arguments) if options[:installation_json]

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

    def self.report_installation(arguments)
      raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?

      puts JSON.generate(installation_identity)
      0
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka doctor [--root DIR]'
        flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
        flags.on('--host NAME', Usage::READERS.keys, Usage::READERS.keys.join(', ')) do |value|
          options[:host] = value
        end
        flags.on('--installation-json', 'JSON installation identity') { options[:installation_json] = true }
        flags.on('-h', '--help', 'Show usage') { options[:help] = true }
      end
    end

    def self.help(parser)
      puts parser
      0
    end

    private_class_method :report, :report_installation, :option_parser, :help

    def self.installation_identity
      path = File.expand_path('../../../../.shaka-install.json', __dir__)
      return JSON.parse(File.read(path)) if File.file?(path)

      { 'schema_version' => 1, 'package_id' => nil, 'version' => Shaka::VERSION,
        'source' => { 'kind' => 'uninstalled', 'repository' => nil, 'revision' => nil,
                      'base_revision' => nil, 'content_sha256' => nil } }
    rescue JSON::ParserError => e
      raise Shaka::Error, "Installed package metadata is invalid: #{e.message}"
    end

    def initialize(root:, host: nil, environment: ENV, system: System.default)
      @root = root
      @stated = !host.nil?
      @host = host || Usage.detected_host
      @source = Checks.new(root: root, host: @host, environment: environment, system: system)
    end

    def checks = @checks ||= @source.call

    def blocked? = checks.any? { |item| item.fetch(:status) == 'failed' }

    def report
      ["Shaka doctor: #{overall.upcase}", context, installation_summary, '',
       *ordered.map { |item| render(item) }].join("\n")
    end

    private

    # Worst first, and stable within a status so the check order stays predictable.
    def ordered = checks.sort_by.with_index { |item, index| [-SEVERITY.fetch(item.fetch(:status)), index] }

    def overall = checks.map { |item| item.fetch(:status) }.max_by { |status| SEVERITY.fetch(status) } || 'healthy'

    # Detection answers nil when several hosts are present and falls back to codex when none
    # is, so the report always says which host it used and how sure it is.
    def context = "host #{named_host} · root #{@root}"

    def installation_summary
      identity = self.class.installation_identity
      source = identity.fetch('source')
      "installation #{identity.fetch('version')} · #{source_summary(source)} · " \
        "package #{identity['package_id'] || 'UNKNOWN'}"
    end

    def source_summary(source)
      return "revision #{source.fetch('revision')}" if source['kind'] == 'revision'
      return 'uninstalled' if source['kind'] == 'uninstalled'

      "development base #{source['base_revision'] || 'UNKNOWN'} " \
        "content #{source.fetch('content_sha256')}"
    end

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
