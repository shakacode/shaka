# frozen_string_literal: true

require 'json'
require 'pathname'
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
    # The levels `agy --effort` accepts. A model ID ends in the one in use, such as
    # `gemini-4-argon-high`; an ID that ends otherwise, such as an orchestrator's, names none.
    EFFORTS = %w[low medium high xhigh max].freeze

    attr_reader :source, :gaps

    # The transcript of the conversation the calling shell belongs to, or nil.
    def self.session_file(environment)
      identity = environment['ANTIGRAVITY_CONVERSATION_ID']
      directory = environment['ANTIGRAVITY_APP_DATA_DIR']
      return unless identity.is_a?(String) && identity.match?(IDENTITY)
      return unless directory.is_a?(String) && Pathname.new(directory).absolute?

      file = File.join(directory, 'brain', identity, '.system_generated', 'logs', 'transcript.jsonl')
      file if File.file?(file)
    end

    def self.parse(line)
      record = JSON.parse(line) if line.valid_encoding?
      record if record.is_a?(Hash)
    rescue JSON::ParserError, EncodingError
      nil
    end

    def self.response?(record)
      record['type'] == 'PLANNER_RESPONSE' || COUNTERS.values.any? { |key| record.key?(key) }
    end

    def self.model(record)
      model = record['model']
      model if model.is_a?(String) && !model.empty?
    end

    def self.effort(model)
      level = model[/-([a-z]+)\z/, 1] if model
      level if EFFORTS.include?(level)
    end

    def initialize(file)
      @gaps = []
      @conversation = File.expand_path(file)[LAYOUT, 1]
      @source = @conversation&.match?(IDENTITY) ? read(file) : unavailable
    end

    private

    # A step written again replaces its earlier line, so the transcript's last word counts.
    def read(file)
      records = {}
      turn = nil
      File.foreach(file, encoding: 'UTF-8') do |line|
        next unless (record = step(line))

        turn = record['step_index'].to_s if record['type'] == 'USER_INPUT'
        records[record['step_index']] = response(record, turn) if self.class.response?(record)
      end
      [records, turn]
    rescue SystemCallError
      unavailable
    end

    def step(line)
      record = self.class.parse(line)
      index = record['step_index'] if record
      index.is_a?(Integer) && index >= 0 ? record : unreadable
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
           'are UNKNOWN. The model is the configured ID, whose last segment is the effort. ' \
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
      # Step numbers repeat across conversations, so each transcript selects its own latest turn.
      files.each { |file| count_selected([load_transcript(file)], turns, all_turns) }
    end

    private

    def load_transcript(file)
      transcript = AntigravityTranscript.new(file)
      @gaps.concat(transcript.gaps)
      transcript.source
    end

    def unreadable
      @gaps << 'Unreadable or unidentifiable records'
      {}
    end
  end
end
