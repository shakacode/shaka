# frozen_string_literal: true

require 'json'
require_relative 'cursor_usage_store'
require_relative 'response_count'

module Shaka
  # Reads persisted Cursor stop-hook usage; transcripts and bubble tokenCount are unused.
  class CursorUsage
    include ResponseCount

    HOST = 'Cursor'
    NOTE = 'Cached input and cache writes are part of input; reasoning output and native total are UNKNOWN. ' \
           'Parent-agent turn only; subagents excluded.'
    LATEST_SCOPE = 'latest generation only per source; earlier turns excluded'
    EVENTS = %w[stop afterAgentResponse].freeze

    attr_reader :responses, :versions, :gaps

    def self.discover
      CursorUsageStore.discover
    end

    def self.persist(raw)
      CursorUsageStore.persist(raw)
    end

    def initialize(files, turns, all_turns: false)
      @responses = {}
      @versions = []
      @gaps = []
      sources = files.map { |file| read(file) }
      records = sources.flat_map { |chosen, _| chosen.values }
      selected(records, wanted_turns(sources, turns), all_turns).each { |record| count(record.except('preferred')) }
    end

    private

    def wanted_turns(sources, turns)
      (turns.empty? ? [sources.dig(0, 1)] : turns).select { |turn| turn?(turn) }
    end

    def selected(records, wanted, all_turns)
      identified = records.select { |record| turn?(record['turn_id']) }
      unreadable if all_turns && identified.size < records.size
      all_turns ? identified : identified.select { |record| wanted.include?(record['turn_id']) }
    end

    def turn?(turn)
      turn.is_a?(String) && !turn.strip.empty?
    end

    def read(file)
      chosen = {}
      last = nil
      File.foreach(file, encoding: 'UTF-8') { |line| last = keep(chosen, response(parse(line))) || last }
      [chosen, last]
    rescue SystemCallError
      [unreadable, nil]
    end

    def keep(chosen, record)
      return unless record

      identity = record['response_id']
      chosen[identity] = record if chosen[identity].nil? || record['preferred']
      identity
    end

    def response(payload)
      return unless payload.is_a?(Hash) && EVENTS.include?(payload['hook_event_name'])
      return unless turn?(payload['generation_id'])

      @versions << payload['cursor_version'] if payload['cursor_version'].is_a?(String)
      { 'response_id' => payload['generation_id'], 'turn_id' => payload['generation_id'],
        'timestamp' => payload['timestamp'], 'preferred' => payload['hook_event_name'] == 'stop',
        'configuration' => configuration(payload), 'usage' => tokens(payload) }
    end

    def configuration(payload)
      ['cursor', payload['model_id'], payload['model'], effort(payload['model_params'])]
    end

    def tokens(payload)
      { 'input_tokens' => payload['input_tokens'], 'cached_input_tokens' => payload['cache_read_tokens'],
        'output_tokens' => payload['output_tokens'], 'cache_write_input_tokens' => payload['cache_write_tokens'] }
    end

    def effort(params)
      found = params.find { |item| item.is_a?(Hash) && item['id'] == 'effort' } if params.is_a?(Array)
      found['value'] if found
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
