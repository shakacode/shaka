# frozen_string_literal: true

require 'json'
require 'pathname'
require_relative 'response_count'

module Shaka
  # Validates and selects the current path through Pi's append-only session tree.
  module PiTree
    private

    def indexed_entries(records)
      entries = {}
      valid = records.all? do |record|
        is_valid = valid_entry?(record) && !entries.key?(record['id']) && known_parent?(entries, record)
        entries[record['id']] = record if is_valid
        is_valid
      end
      entries if valid && !entries.empty?
    end

    def valid_entry?(record)
      record.is_a?(Hash) && record['type'].is_a?(String) && identity?(record['id']) &&
        (record['parentId'].nil? || identity?(record['parentId']))
    end

    def known_parent?(entries, record)
      record['parentId'].nil? || entries.key?(record['parentId'])
    end

    def identity?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    def active_branch(entries)
      branch = []
      entry = entries.values.last
      while entry
        branch << entry
        entry = entries[entry['parentId']]
      end
      branch.reverse
    end
  end

  # Extracts aggregate-safe records from one persistent Pi session tree.
  class PiSession
    include PiTree

    ID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    VERSIONS = [2, 3].freeze

    attr_reader :gaps, :source, :version

    def self.header(file)
      JSON.parse(File.open(file, encoding: 'UTF-8', &:readline))
    rescue JSON::ParserError, EncodingError, SystemCallError, EOFError
      nil
    end

    def initialize(file)
      @gaps = []
      @source = read(file)
    end

    private

    def read(file)
      records = parsed_records(file)
      return unavailable unless records

      header = records.shift
      return unavailable unless valid_header?(header)

      @version = header['version'].to_s
      entries = indexed_entries(records)
      return unavailable unless entries

      extract(active_branch(entries), header['id'])
    rescue SystemCallError, EncodingError
      unavailable
    end

    def parsed_records(file)
      records = File.foreach(file, encoding: 'UTF-8').map { |line| parse(line) }
      records if records.all?
    end

    def valid_header?(header)
      header.is_a?(Hash) && header['type'] == 'session' && header['id'].is_a?(String) &&
        header['id'].match?(ID) && VERSIONS.include?(header['version'])
    end

    def extract(branch, session)
      state = { model: nil, effort: nil, turn: nil }
      records = {}
      branch.each { |entry| consume(records, state, entry, session) }
      [records, state[:turn]]
    end

    def consume(records, state, entry, session)
      case entry['type']
      when 'model_change' then state[:model] = setting(entry['modelId'])
      when 'thinking_level_change' then state[:effort] = setting(entry['thinkingLevel'])
      when 'message' then consume_message(records, state, entry, session)
      end
    end

    def consume_message(records, state, entry, session)
      message = entry['message']
      return unreadable unless message.is_a?(Hash)

      state[:turn] = entry['id'] if message['role'] == 'user'
      keep_response(records, state, entry, message, session)
    end

    def setting(value)
      return value if value.is_a?(String) && !value.empty?

      unreadable
      nil
    end

    def keep_response(records, state, entry, message, session)
      return unless message['role'] == 'assistant'

      identity = "#{session}:#{entry['id']}"
      records[identity] = response(identity, state, entry, message)
    end

    def response(identity, state, entry, message)
      { 'response_id' => identity, 'turn_id' => state[:turn], 'timestamp' => entry['timestamp'],
        'configuration' => [message['provider'], state[:model], message['model'], state[:effort]],
        'usage' => token_usage(message['usage']) }
    end

    def token_usage(usage)
      return {} unless usage.is_a?(Hash)

      tokens = mapped_tokens(usage)
      return unreadable if contradictory?(tokens)

      tokens
    end

    def mapped_tokens(usage)
      { 'input_tokens' => usage['input'], 'cached_input_tokens' => usage['cacheRead'],
        'output_tokens' => usage['output'], 'reasoning_output_tokens' => nil,
        'cache_write_input_tokens' => usage['cacheWrite'], 'total_tokens' => usage['totalTokens'] }
    end

    def contradictory?(tokens)
      categories = %w[input_tokens cached_input_tokens output_tokens cache_write_input_tokens]
                   .map { |field| tokens[field] }
      total = tokens['total_tokens']
      [*categories, total].all? { |value| value.is_a?(Integer) && value >= 0 } && categories.sum != total
    end

    def parse(line)
      record = JSON.parse(line)
      record if record.is_a?(Hash)
    rescue JSON::ParserError, EncodingError
      nil
    end

    def unavailable
      unreadable
      [{}, nil]
    end

    def unreadable
      @gaps << 'Unreadable or unidentifiable records'
      {}
    end
  end

  # Reads only the active branch and retains no Pi session content.
  class PiUsage
    include ResponseCount

    HOST = 'Pi'
    NOTE = 'Input excludes cache reads and writes; reasoning output is UNKNOWN because Pi does not expose it ' \
           'separately.'
    LATEST_SCOPE = 'latest user turn on the active branch; earlier turns and abandoned branches excluded'
    INCLUSIVE_INPUT = false

    attr_reader :responses, :versions, :gaps

    def self.discover
      identity = ENV.fetch('PI_SESSION_ID', nil)
      file = ENV.fetch('PI_SESSION_FILE', nil)
      return [] unless identity&.match?(PiSession::ID) && file.is_a?(String) && Pathname.new(file).absolute?

      header = PiSession.header(file)
      matching_source?(header, identity) ? [file] : []
    end

    def self.matching_source?(header, identity)
      header.is_a?(Hash) && header['type'] == 'session' && header['id'] == identity &&
        PiSession::VERSIONS.include?(header['version'])
    end

    private_class_method :matching_source?

    def initialize(files, turns, all_turns: false)
      @responses = {}
      @versions = []
      @gaps = []
      unreadable if files.empty?
      sources = files.map { |file| load_session(file) }
      count_selected(sources, turns, all_turns)
    end

    private

    def load_session(file)
      session = PiSession.new(file)
      @versions << session.version if session.version
      @gaps.concat(session.gaps)
      session.source
    end

    def unreadable
      @gaps << 'Unreadable or unidentifiable records'
      {}
    end
  end
end
