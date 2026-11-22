# frozen_string_literal: true

require 'json'
require 'pathname'
require_relative '../error'
require_relative 'response_count'

module Shaka
  # Reads one Antigravity conversation transcript (tested with CLI 1.5.14), keeping only usage
  # metadata. Each line is one step; a step's content, thinking, and tool calls are never kept.
  class AntigravityTranscript
    IDENTITY = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/
    # The transcript names no conversation, so a response is identified by the directory
    # Antigravity keeps it in. A copy saved elsewhere has no identity to deduplicate by.
    LAYOUT = %r{/brain/([^/]+)/\.system_generated/logs/[^/]+\z}
    COUNTERS = { 'input_tokens' => 'input_tokens', 'cached_input_tokens' => 'cache_read_tokens',
                 'output_tokens' => 'output_tokens' }.freeze
    KEPT = ['step_index', 'type', 'created_at', 'model', *COUNTERS.values].freeze
    # A model ID ends in its effort, such as `gemini-4-argon-high`. These are the endings
    # `agy models` lists; an ID that ends otherwise, such as a gateway's own model, names none.
    EFFORTS = %w[low medium high xhigh].freeze

    attr_reader :source, :gaps, :conversation

    # The transcript of the conversation the calling shell belongs to, or nil.
    def self.session_file(environment)
      identity = environment['ANTIGRAVITY_CONVERSATION_ID']
      directory = environment['ANTIGRAVITY_APP_DATA_DIR']
      return unless identity.is_a?(String) && identity.match?(IDENTITY)
      return unless directory.is_a?(String) && Pathname.new(directory).absolute?

      file = File.join(directory, 'brain', identity, '.system_generated', 'logs', 'transcript.jsonl')
      file if File.file?(file)
    end

    # Steps in index order, so a step written again keeps its last line and its place, and the
    # number of lines that are not steps. Only usage metadata leaves this method.
    def self.steps(file)
      found = {}
      skipped = 0
      File.foreach(file, encoding: 'UTF-8') do |line|
        step = parse(line)
        step ? found[step['step_index']] = step : skipped += 1
      end
      [found.sort.map(&:last), skipped]
    end

    def self.parse(line)
      record = JSON.parse(line) if line.valid_encoding?
      return unless record.is_a?(Hash) && record['type'].is_a?(String)

      index = record['step_index']
      record.slice(*KEPT) if index.is_a?(Integer) && index >= 0
    rescue JSON::ParserError, EncodingError
      nil
    end

    def self.user_input?(step) = step['type'] == 'USER_INPUT'

    def self.response?(step)
      step['type'] == 'PLANNER_RESPONSE' || COUNTERS.values.any? { |key| step.key?(key) }
    end

    def self.model(step)
      model = step['model']
      model if model.is_a?(String) && !model.empty?
    end

    def self.effort(model)
      level = model[/-([a-z]+)\z/, 1] if model
      level if EFFORTS.include?(level)
    end

    def initialize(file)
      @gaps = []
      identity = File.expand_path(file)[LAYOUT, 1]
      @conversation = identity if identity&.match?(IDENTITY)
      @source = @conversation ? read(file) : unavailable
    end

    private

    def read(file)
      steps, skipped = self.class.steps(file)
      unreadable if skipped.positive?
      responses(steps)
    rescue SystemCallError
      unavailable
    end

    def responses(steps)
      turn = nil
      records = steps.each_with_object({}) do |step, found|
        turn = step['step_index'].to_s if self.class.user_input?(step)
        found[step['step_index']] = response(step, turn) if self.class.response?(step)
      end
      [records, turn]
    end

    def response(record, turn)
      model = self.class.model(record)
      { 'response_id' => "#{@conversation}:#{record['step_index']}", 'turn_id' => turn,
        'timestamp' => record['created_at'],
        'configuration' => [nil, model, nil, self.class.effort(model)], 'usage' => token_usage(record) }
    end

    # Reasoning is part of output and cache writes are not recorded, so neither has a counter here.
    def token_usage(record)
      COUNTERS.transform_values do |key|
        value = record[key]
        value if value.is_a?(Integer) && value >= 0
      end
    end

    def unavailable
      unreadable
      [{}, nil]
    end

    def unreadable
      @gaps << 'Unreadable or unidentifiable records'
      nil
    end
  end

  # Selects responses from Antigravity transcripts without retaining conversation content.
  class AntigravityUsage
    include ResponseCount

    HOST = 'Antigravity'
    NOTE = 'Input excludes cache reads; reasoning output is part of output. Cache writes and native total ' \
           'are UNKNOWN. The model is the configured ID; its last segment is the effort when it names a level. ' \
           'Subagent conversations excluded.'
    LATEST_SCOPE = 'latest user turn of each conversation; earlier turns excluded'
    INCLUSIVE_INPUT = false

    attr_reader :responses, :versions, :gaps

    def self.discover = [AntigravityTranscript.session_file(ENV)].compact

    def initialize(files, turns, all_turns: false)
      @responses = {}
      @versions = []
      @gaps = []
      unreadable if files.empty?
      transcripts = files.map { |file| AntigravityTranscript.new(file) }
      one_conversation!(transcripts) if turns.any?
      # Step numbers repeat across conversations, so each transcript selects its own latest turn.
      transcripts.each { |transcript| count_selected([load(transcript)], turns, all_turns) }
    end

    private

    # The same turn number names unrelated work in two conversations. A transcript without an
    # identity counts nothing, so it reports its own gap instead of standing for a second one.
    def one_conversation!(transcripts)
      return if transcripts.filter_map(&:conversation).uniq.size < 2

      raise Error, '--turn selects steps of one Antigravity conversation; report each conversation separately.'
    end

    def load(transcript)
      @gaps.concat(transcript.gaps)
      transcript.source
    end

    def unreadable
      @gaps << 'Unreadable or unidentifiable records'
      {}
    end
  end
end
