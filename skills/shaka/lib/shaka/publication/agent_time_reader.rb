# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'agent_time_codex'
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
    include AgentTimeCodex

    Turn = Struct.new(:from, :to, :prompted)

    attr_reader :turns

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
      @open.each_value { |started, _category| cross(started) } if @turns.any?
      self
    end

    # Finished calls, and each call still running counted to the last record, in its category. A call that
    # started before the task counts from the task start.
    def calls
      last = @turns.last&.to
      running = @open.values.filter_map { |started, category| [category, clip(started), last] if last }
      @calls + running.select { |_category, from, to| to >= from }
    end

    private

    # Only the agent's own records extend a turn; host bookkeeping written later does not. Records before the
    # task start only open and close calls, so a call running across the start pairs with its result.
    def visit(record, at)
      return unless at

      @before = @since && at < @since
      agent = %w[response_item event_msg].include?(record['type']) ? codex?(record, at) : claude?(record, at)
      return if @before || !agent

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
      blocks.each { |block| claude_block(block, at, message['id']) }
      true
    end

    # The model starts a new message only after every earlier call returned, so a call still open then
    # finished without a recorded result. Like a call never answered, it is left out.
    def settle(message)
      @open.reject! { |_id, (_at, _category, opener)| opener && message && opener != message }
    end

    # After a reply that ended its turn, the next record starts one even without a person's message, such
    # as a host wake, so the idle time before it is not counted as work.
    def claude_turn(record, content, blocks, at)
      prompted = record['type'] == 'user' && prompt?(content, blocks)
      # A message sent while a tool still runs joins the running turn rather than ending it.
      start_turn(at, prompted:) if !@before && ((prompted && @open.empty?) || @ended)
      end_turn(record)
    end

    # A call with no result by the end of its turn was interrupted; it is not left running for hours.
    def end_turn(record)
      message = hash(record['message'])
      settle(message['id']) if record['type'] == 'assistant'
      stop = message['stop_reason']
      @ended = record['type'] == 'assistant' && !stop.nil? && stop != 'tool_use'
      @open.clear if @ended
    end

    def claude_block(block, at, message)
      case block['type']
      when 'tool_use' then open_call(block['id'], block['name'], hash(block['input'])['command'], at, message)
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

    def start_turn(at, prompted: true) = @turns << Turn.new(at, at, prompted)

    def open_call(id, name, command, at, message = nil)
      return unless id.is_a?(String) && name.is_a?(String)

      @open[id] = [at, ToolCategory.call(name, command.is_a?(Array) ? command : command.to_s), message]
    end

    def close_call(id, at)
      started, category = @open.delete(id)
      return unless started && at >= clip(started)

      cross(started)
      @calls << [category, clip(started), at]
    end

    # A call that ran across the task start, shown by its result or by still running at the end, puts the task
    # start inside the first turn.
    def cross(started)
      return unless @since && started < @since

      @turns.empty? ? start_turn(@since, prompted: false) : @turns.first.from = @since
    end

    def clip(started) = @since && started < @since ? @since : started

    def time(value)
      Time.iso8601(value).utc if value.is_a?(String)
    rescue ArgumentError
      nil
    end
  end
end
