# frozen_string_literal: true

require 'json'
require_relative 'response_count'

module Shaka
  # Reads Claude Code session transcripts (tested with 2.1.270 and 2.1.272), keeping only usage metadata.
  class ClaudeUsage
    include ResponseCount

    HOST = 'Claude Code'
    NOTE = 'Anthropic input excludes cached input and cache writes; reasoning output is part of output.'
    LATEST_SCOPE = 'latest turn of the session, including its subagents; earlier turns excluded'

    attr_reader :responses, :versions, :gaps

    def self.discover
      identity = ENV.fetch('CLAUDE_CODE_SESSION_ID', nil)
      return [] unless identity&.match?(/\A[0-9a-f-]{36}\z/)

      home = ENV.fetch('CLAUDE_CONFIG_DIR', File.expand_path('~/.claude'))
      sessions = Dir.glob(File.join(home, 'projects', '*', "#{identity}.jsonl"))
      return [] unless sessions.one? && session_of(sessions.first) == identity

      sessions + Dir.glob(File.join(File.dirname(sessions.first), identity, 'subagents', '*.jsonl'))
    end

    def self.session_of(file)
      File.foreach(file, encoding: 'UTF-8') do |line|
        record = JSON.parse(line)
        return record['sessionId'] if record.is_a?(Hash) && record.key?('sessionId')
      rescue JSON::ParserError, EncodingError
        next
      end
      nil
    rescue SystemCallError
      nil
    end

    private_class_method :session_of

    def initialize(files, turns, all_turns: false)
      @responses = {}
      @versions = []
      @gaps = []
      sources = files.map { |file| read(file) }
      count_selected(sources, turns, all_turns)
    end

    private

    # Streamed lines repeat a response; the last line carries its final usage.
    def read(file)
      records = {}
      turn = nil
      File.foreach(file, encoding: 'UTF-8') do |line|
        record = parse(line)
        turn = record['promptId'] if record['type'] == 'user'
        records.merge!(response(record, turn)) if record['type'] == 'assistant'
      end
      [records, turn]
    rescue SystemCallError
      [unreadable, nil]
    end

    def response(record, turn)
      message = record['message'].is_a?(Hash) ? record['message'] : {}
      @versions << record['version'] if record['version'].is_a?(String)
      { message['id'] => { 'response_id' => message['id'], 'turn_id' => turn, 'timestamp' => record['timestamp'],
                           'configuration' => ['anthropic', 'UNKNOWN', message['model'], record['effort']],
                           'usage' => tokens(message['usage']) } }
    end

    def tokens(usage)
      return {} unless usage.is_a?(Hash)

      details = usage['output_tokens_details']
      { 'input_tokens' => usage['input_tokens'], 'cached_input_tokens' => usage['cache_read_input_tokens'],
        'output_tokens' => usage['output_tokens'], 'cache_write_input_tokens' => usage['cache_creation_input_tokens'],
        'reasoning_output_tokens' => (details['thinking_tokens'] if details.is_a?(Hash)) }
    end

    def parse(line)
      record = JSON.parse(line)
      record.is_a?(Hash) ? record : unreadable
    rescue JSON::ParserError, EncodingError
      unreadable
    end

    def unreadable
      @gaps << 'Unreadable or unidentifiable records'
      {}
    end
  end
end
