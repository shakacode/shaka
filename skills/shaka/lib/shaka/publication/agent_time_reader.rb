# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'tool_category'

module Shaka
  # Reads one Claude Code or Codex session transcript and returns where the agent's time went: how long
  # its turns ran, how long each fixed kind of tool call took, and how long it waited on a person. Only
  # timestamps, tool names, and the category a command falls in are used; no command, prompt, or
  # output text leaves this reader.
  class AgentTimeReader
    # The host writes its own wakes, such as a finished background task or a CI event, as user
    # messages that open with one of these tags. A person's message can open with other tags.
    HOST_MESSAGE = /\A\s*<(?:task-notification|ci-monitor-event|side-sessions-event|system-reminder)>/
    Turn = Struct.new(:from, :to, :prompted)

    attr_reader :turns, :calls

    def self.read(path, since: nil) = new(since).tap { |reader| reader.parse(path) }

    def initialize(since)
      @since = since
      @turns = []
      @calls = []
      @open = {}
    end

    def parse(path)
      File.foreach(path, encoding: 'UTF-8') do |line|
        record = JSON.parse(line)
        visit(record, time(record['timestamp'])) if record.is_a?(Hash)
      rescue JSON::ParserError, EncodingError
        next
      end
      self
    end

    private

    # Only the agent's own records extend a turn; host bookkeeping written later does not.
    def visit(record, at)
      return unless at && (@since.nil? || at >= @since)
      return unless %w[response_item event_msg].include?(record['type']) ? codex?(record, at) : claude?(record, at)

      # A turn already running when the task started opens at the first record inside the task.
      start_turn(at, prompted: false) if @turns.empty?
      # A record written out of order never moves the turn's end earlier.
      @turns.last.to = [@turns.last.to, at].max
    end

    # A person's prompt opens a turn; tool calls and their results pair by id.
    def claude?(record, at)
      return false if record['isSidechain'] || record['isMeta'] || !%w[user assistant].include?(record['type'])

      message = hash(record['message'])
      content = message['content']
      blocks = content.is_a?(Array) ? content.grep(Hash) : []
      claude_turn(record, content, blocks, at)
      blocks.each { |block| claude_block(block, at) }
      true
    end

    # After a reply that ended its turn, the next record starts one even without a person's message, such
    # as a host wake, so the idle time before it is not counted as work.
    def claude_turn(record, content, blocks, at)
      prompted = record['type'] == 'user' && prompt?(content, blocks)
      # A message sent while a tool still runs joins the running turn rather than ending it.
      start_turn(at, prompted:) if (prompted && @open.empty?) || @ended
      stop = hash(record['message'])['stop_reason']
      @ended = record['type'] == 'assistant' && !stop.nil? && stop != 'tool_use'
    end

    def claude_block(block, at)
      case block['type']
      when 'tool_use' then open_call(block['id'], block['name'], hash(block['input'])['command'], at)
      when 'tool_result' then close_call(block['tool_use_id'], at)
      end
    end

    # Transcript fields are host data, so one that is not an object reads as empty.
    def hash(value) = value.is_a?(Hash) ? value : {}

    # A person's message, such as text or an image, not a host wake or a tool result.
    def prompt?(content, blocks)
      return !content.match?(HOST_MESSAGE) if content.is_a?(String)
      return false if blocks.any? { |block| block['type'] == 'tool_result' }

      texts = message_texts(blocks)
      texts.empty? ? blocks.any? { |block| block['type'] == 'image' } : texts.any? { |text| !text.match?(HOST_MESSAGE) }
    end

    def message_texts(blocks)
      blocks.filter_map { |block| block['text'] if block['type'] == 'text' && block['text'].is_a?(String) }
            .reject(&:empty?)
    end

    def codex?(record, at)
      payload = record['payload']
      return false unless payload.is_a?(Hash)

      codex_event(payload, at)
      record['type'] == 'response_item' || %w[task_started task_complete].include?(payload['type'])
    end

    def codex_event(payload, at)
      case payload['type']
      when 'task_started' then start_turn(at)
      when 'function_call', 'custom_tool_call', 'local_shell_call'
        open_call(payload['call_id'], payload['name'] || 'local_shell', codex_command(payload), at)
      when 'function_call_output', 'custom_tool_call_output' then close_call(payload['call_id'], at)
      end
    end

    # A local shell call keeps its command as a word list under `action`; the list stays a list.
    def codex_command(payload)
      arguments_command(payload['arguments']) || payload['input'] || hash(payload['action'])['command']
    end

    # A function call's arguments are JSON that names its command in `cmd` or `command`.
    def arguments_command(arguments)
      return unless arguments.is_a?(String)

      parsed = JSON.parse(arguments)
      parsed.is_a?(Hash) ? parsed['cmd'] || parsed['command'] || arguments : arguments
    rescue JSON::ParserError
      arguments
    end

    def start_turn(at, prompted: true) = @turns << Turn.new(at, at, prompted)

    def open_call(id, name, command, at)
      return unless id.is_a?(String) && name.is_a?(String)

      @open[id] = [at, ToolCategory.call(name, command.is_a?(Array) ? command : command.to_s)]
    end

    def close_call(id, at)
      started, category = @open.delete(id)
      @calls << [category, started, at] if started && at >= started
    end

    def time(value)
      Time.iso8601(value).utc if value.is_a?(String)
    rescue ArgumentError
      nil
    end
  end
end
