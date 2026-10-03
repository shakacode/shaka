# frozen_string_literal: true

require 'open3'
require 'optparse'
require_relative 'error'
require_relative 'usage/usage'
require_relative 'doctor/bounded_command'
require_relative 'doctor/checks'
require_relative 'local_review/path_guard'
require_relative 'doctor/system'
require_relative 'doctor/cursor_stop_hook'
require_relative 'doctor/installation_identity'
require_relative 'doctor/command'
require_relative 'doctor/reviewer_probe'

module Shaka
  # Reports whether this machine can run the workflow and publish a complete pull request.
  # Read-only: it inspects the environment and changes no repository and no setting.
  class Doctor
    SEVERITY = { 'healthy' => 0, 'degraded' => 1, 'failed' => 2 }.freeze
    # Long enough that a slow network answer is not mistaken for a hang, short enough that a
    # stalled credential helper does not look like a working command.
    TIMEOUT = 15
    RUNNER = BoundedCommand.new(timeout: TIMEOUT)

    extend Command

    def self.run(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return help(parser) if options[:help]

      return report_installation(arguments, options) if options[:installation_json]

      report(arguments, options)
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def self.report(arguments, options)
      raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?

      validate_probe_options!(options)
      subject = new(root: File.realpath(options.fetch(:root, Dir.pwd)), host: options[:host],
                    probe_timeout: (options.fetch(:probe_timeout, 30) if options[:probe_reviewers]))
      puts subject.report
      subject.blocked? ? 1 : 0
    end

    def self.report_installation(arguments, options)
      raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?
      if options.keys.any? { |key| key != :installation_json }
        raise OptionParser::InvalidArgument, 'flags cannot be combined'
      end

      puts JSON.generate(InstallationIdentity.read)
      0
    end

    def self.help(parser)
      puts parser
      0
    end

    private_class_method :report, :report_installation, :help

    def initialize(root:, host: nil, environment: ENV, system: System.default, probe_timeout: nil)
      @root = root
      @stated = !host.nil?
      @host = host || Usage.detected_host
      @source = Checks.new(root: root, host: @host, environment: environment, system: system,
                           probe_reviewers: !probe_timeout.nil?)
      @probe = ReviewerProbe.new(root:, path: environment.fetch('PATH', ''), timeout: probe_timeout) if probe_timeout
    end

    def checks
      @checks ||= begin
        items = @source.call
        items << @probe.for_repository(items.find { |item| item[:name] == 'Repository seam' }) if @probe
        items
      end
    end

    def blocked?
      checks.any? { |item| item.fetch(:status) == 'failed' } || installation_failed?
    end

    def report
      ["Shaka doctor: #{overall.upcase}", context, installation_summary, '',
       *ordered.map { |item| render(item) }, '', next_step].join("\n")
    end

    private

    # Worst first, and stable within a status so the check order stays predictable.
    def ordered = checks.sort_by.with_index { |item, index| [-SEVERITY.fetch(item.fetch(:status)), index] }

    def overall
      return 'failed' if installation_failed?

      checks.map { |item| item.fetch(:status) }.max_by { |status| SEVERITY.fetch(status) } || 'healthy'
    end

    # Detection answers nil when several hosts are present and falls back to codex when none
    # is, so the report always says which host it used and how sure it is.
    def context = "host #{named_host} · root #{@root}"

    def installation_summary = @installation_summary ||= render_installation_summary

    def installation_failed?
      installation_summary
      !@installation_error.nil?
    end

    def render_installation_summary
      identity = InstallationIdentity.read
      source = identity.fetch('source')
      "installation #{identity.fetch('version')} · #{source_summary(source)} · " \
        "package #{identity['package_id'] || 'UNKNOWN'}"
    rescue Shaka::Error, KeyError, TypeError, SystemCallError => e
      @installation_error = e
      "[FAILED] Installation — #{e.message}"
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

    def next_step
      return 'Next step: resolve the FAILED checks above, then rerun `shaka doctor`.' if blocked?

      'Next step: give your coding agent a small task with Shaka. Run `shaka` for example prompts. ' \
        'Follow any setup advice above when you want another reviewer.'
    end
  end
end
