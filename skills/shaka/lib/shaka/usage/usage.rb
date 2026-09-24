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
      groups = table_groups
      return "| Metric |\n| --- |" if groups.empty?

      headers = column_headers(groups.keys)
      lines = [line(['Metric', *headers]), line(['---'] * (headers.size + 1))]
      metric_cells(groups).each { |label, values| lines << line([label, *values]) }
      lines.join("\n")
    end

    def table_groups
      grouped = @responses.group_by { |record| record['configuration'] }
      grouped.empty? && context_row ? { context_row => [] } : grouped
    end

    def column_headers(configurations)
      labeled = configurations.map { |configuration| configuration.map { |value| safe(value) } }
      unique_labels(labeled) || sequence_labels(labeled)
    end

    def unique_labels(labeled)
      label_candidates(labeled).find { |names| names.uniq.size == names.size }
    end

    def label_candidates(labeled)
      [0, 1, 2].map { |index| labeled.map { |cells| cells[index] } } +
        [[0, 1], [0, 1, 3]].map { |indexes| join_cells(labeled, indexes) }
    end

    def join_cells(labeled, indexes)
      labeled.map { |cells| indexes.map { |index| cells[index] }.join(' ') }
    end

    def sequence_labels(labeled)
      labeled.map.with_index { |cells, index| "#{cells[0]}-#{index + 1}" }
    end

    def metric_cells(groups)
      configs = groups.keys.map { |configuration| configuration.map { |value| safe(value) } }
      settings = Usage::SETTING_LABELS.zip(configs.transpose)
      tokens = Usage::METRIC_FIELDS.map do |label, field|
        [label, groups.values.map { |group| total_field(group, field) }]
      end
      settings + tokens
    end

    def line(cells) = "| #{cells.join(' | ')} |"

    def total_field(group, field)
      values = group.map { |record| record['usage'].is_a?(Hash) ? record['usage'][field] : nil }
      countable?(values) ? values.sum : 'UNKNOWN'
    end

    def countable?(values)
      values.any? && values.all? { |value| value.is_a?(Integer) && value >= 0 }
    end

    def context_row
      return unless @inferred && @options[:turns].empty?

      @source.context_configuration if @source.respond_to?(:context_configuration)
    end

    def cost_responses
      return @responses unless @responses.empty? && context_row

      [{ 'configuration' => context_row, 'usage' => {} }]
    end

    def reviewer_coverage
      local = local_review_included? ? 'included below' : 'UNKNOWN'
      gaps = @source.gaps.uniq.join('; ')
      "Local adversarial reviewer usage: #{local}. External reviewer/tool-model usage: UNKNOWN. #{gaps}"
    end

    def local_review_included?
      return false unless @options[:contribution] == 'review'

      table_groups.any? do |_configuration, group|
        Usage::METRIC_FIELDS.any? { |_label, field| total_field(group, field).is_a?(Integer) }
      end
    end
  end

  # Refuses explicit turns that name nothing in a source that has readable turns.
  module UsageTurns
    FIELDS = { 'codex' => 'turn_id', 'claude-code' => 'promptId', 'cursor' => 'generation_id',
               'opencode' => 'user message id', 'pi' => 'user entry id' }.freeze

    # A mistyped turn would otherwise publish an empty table that reads as missing records.
    # A source with no readable turns keeps its own unavailable-records report instead.
    def print_report
      missing = unmatched_turns
      if missing.empty?
        puts report
        return 0
      end

      warn "shaka usage: --turn #{missing.join(', ')} matched no readable response; " \
           "#{@options[:host]} turns use the #{FIELDS.fetch(@options[:host])} field"
      1
    end

    private

    def unmatched_turns
      missing = @options[:turns].uniq - turn_ids(@responses)
      missing.empty? || turn_ids(all_responses).empty? ? [] : missing
    end

    def turn_ids(responses) = responses.map { |record| record['turn_id'] }

    def all_responses
      Usage::READERS.fetch(@options[:host]).new(@options[:files], [], all_turns: true).responses.values
    end
  end

  # Read-only reporting of per-response usage records from a supported host.
  class Usage
    include UsageTable
    include UsageTurns

    SETTING_LABELS = ['Provider', 'Configured model', 'Routed model', 'Effort'].freeze
    METRIC_FIELDS = [
      ['Input', 'input_tokens'],
      ['Cached input', 'cached_input_tokens'],
      ['Output', 'output_tokens'],
      ['Reasoning output', 'reasoning_output_tokens'],
      ['Cache writes', 'cache_write_input_tokens'],
      ['Native total', 'total_tokens']
    ].freeze
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

      new(options).print_report
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
        #{CostEstimate.new(cost_responses, inclusive_input: @source.class::INCLUSIVE_INPUT).report.rstrip}

        #{reviewer_coverage}
        Native usage is PARTIAL. #{count}. Scope: #{turn_scope}.

        <details>
        <summary>Token detail</summary>

        #{@options[:commit]} / #{@options[:contribution]}
        SHARED source interval: #{interval}. Snapshot through the last observed response.
        Source selection: #{@inferred ? 'host context' : 'explicit files'}.
        #{@source.class::HOST} source versions: #{versions}.
        #{@source.class::NOTE}

        #{rows}

        </details>
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
