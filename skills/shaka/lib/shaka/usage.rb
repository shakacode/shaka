# frozen_string_literal: true

require 'optparse'
require_relative 'claude_usage'
require_relative 'codex_usage'
require_relative 'cost_estimate'
require_relative 'cursor_usage'
require_relative 'opencode_usage'
require_relative 'pi_usage'

module Shaka
  # Host-context fallback rows when a reader has no per-response records.
  module UsageTable
    private

    def rows
      grouped = @responses.group_by { |record| record['configuration'] }
      grouped = { context_row => [] } if grouped.empty? && context_row
      grouped.map do |configuration, group|
        "| #{(configuration.map { |value| safe(value) } + totals(group)).join(' | ')} |"
      end.join("\n")
    end

    def totals(group)
      Usage::FIELDS.map { |field| total_field(group, field) }
    end

    def total_field(group, field)
      values = group.map { |record| record['usage'].is_a?(Hash) ? record['usage'][field] : nil }
      countable?(values) ? values.sum : 'UNKNOWN'
    end

    def countable?(values)
      values.any? && values.all? { |value| value.is_a?(Integer) && value >= 0 }
    end

    def context_row
      return unless @inferred

      @source.context_configuration if @source.respond_to?(:context_configuration)
    end

    def cost_responses
      return @responses unless @responses.empty? && context_row

      [{ 'configuration' => context_row, 'usage' => {} }]
    end
  end

  # Read-only reporting of per-response usage records from a supported host.
  class Usage
    include UsageTable

    FIELDS = %w[input_tokens cached_input_tokens output_tokens reasoning_output_tokens
                cache_write_input_tokens total_tokens].freeze
    READERS = { 'codex' => CodexUsage, 'claude-code' => ClaudeUsage, 'cursor' => CursorUsage,
                'opencode' => OpencodeUsage, 'pi' => PiUsage }.freeze
    HOST_CONTEXT = { 'codex' => 'CODEX_THREAD_ID', 'claude-code' => 'CLAUDE_CODE_SESSION_ID',
                     'cursor' => 'CURSOR_CONVERSATION_ID', 'opencode' => 'OPENCODE_SESSION_ID',
                     'pi' => 'PI_CODING_AGENT' }.freeze

    def self.run(arguments)
      options = { files: [], turns: [], host: detected_host }
      parser(options).parse!(arguments)
      puts parser(options) if options[:help]
      return 0 if options[:help]

      raise OptionParser::InvalidArgument unless arguments.empty? && valid_mapping?(options)

      puts new(options).report
      0
    rescue OptionParser::ParseError
      warn 'shaka usage: invalid options; use shaka usage --help'
      1
    end

    def self.parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka usage --commit SHA[,SHA] --contribution NAME [options]'
        source_options(flags, options)
        flags.on('--commit SHA', 'Affected full commit SHAs, comma separated') { |v| options[:commit] = v }
        flags.on('--contribution NAME', 'Contribution category (see guide)') { |v| options[:contribution] = v }
        flags.on('-h', '--help') { options[:help] = true }
      end
    end

    def self.source_options(flags, options)
      flags.on('--host NAME', READERS.keys, 'codex, claude-code, cursor, opencode, or pi') { |v| options[:host] = v }
      flags.on('--file PATH', 'Native transcript or export file; repeat for contributors/resumes') do |v|
        options[:files] << v
      end
      flags.on('--session ID', 'OpenCode session; needs --host opencode') { |v| options[:files] << "session:#{v}" }
      flags.on('--all-turns', 'Only for sources dedicated to this task') { options[:all_turns] = true }
      flags.on('--turn ID', 'Select a native turn; repeat for a shared interval') { |v| options[:turns] << v }
    end

    def self.detected_host
      found = HOST_CONTEXT.select { |host, variable| host == 'pi' ? ENV[variable] == 'true' : ENV.key?(variable) }.keys
      found.size > 1 ? nil : found.first || 'codex'
    end

    def self.valid_mapping?(options)
      commits = options[:commit].to_s.split(',')
      options[:host] && !(options[:all_turns] && options[:turns].any?) &&
        !commits.empty? && commits.all? { |commit| commit.match?(/\A[0-9a-f]{40}\z/) } &&
        %w[implementation review integration shared-planning].include?(options[:contribution])
    end

    def initialize(options)
      @options = options
      reader = READERS.fetch(options[:host])
      @inferred = options[:files].empty?
      @options[:files] = reader.discover if @inferred
      @source = reader.new(@options[:files], @options[:turns], all_turns: @options[:all_turns])
      @responses = @source.responses.values
    end

    def report
      <<~MARKDOWN
        Native usage is PARTIAL. #{count}. Scope: #{turn_scope}.
        External reviewer/tool-model usage: UNKNOWN. #{@source.gaps.uniq.join('; ')}

        <details>
        <summary>Native usage</summary>

        #{@options[:commit]} / #{@options[:contribution]}
        SHARED source interval: #{interval}. Snapshot through the last observed response.
        Source selection: #{@inferred ? 'host context' : 'explicit files'}.
        #{@source.class::HOST} source versions: #{versions}.
        #{@source.class::NOTE}

        | Provider | Configured model | Routed model | Effort | Input | Cached input | Output | Reasoning output | Cache writes | Native total |
        | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
        #{rows}

        </details>
        #{CostEstimate.new(cost_responses, inclusive_input: @source.class::INCLUSIVE_INPUT).report}
      MARKDOWN
    end

    private

    def turn_scope
      return 'all turns in selected sources' if @options[:all_turns]

      @options[:turns].empty? ? @source.class::LATEST_SCOPE : 'explicitly selected turns'
    end

    def count
      @responses.empty? ? 'Responses: UNKNOWN (no readable per-response records)' : "#{@responses.size} responses"
    end

    def versions
      @source.versions.empty? ? 'UNKNOWN' : @source.versions.uniq.map { |version| safe(version) }.join(', ')
    end

    def interval
      timestamps = @responses.filter_map do |record|
        stamp = record['timestamp']
        stamp if stamp.is_a?(String) && stamp.match?(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z\z/)
      end
      timestamps.empty? ? 'UNKNOWN' : timestamps.minmax.join(' through ')
    end

    def safe(value)
      value.is_a?(String) && value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._:-]{0,79}\z/) ? value : 'UNKNOWN'
    end
  end
end
