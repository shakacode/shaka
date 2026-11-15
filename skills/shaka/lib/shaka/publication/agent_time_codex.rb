# frozen_string_literal: true

require 'json'

module Shaka
  # Reads Codex transcript records for AgentTimeReader: its task events open and close turns, and its function,
  # custom tool, and local shell calls pair with their outputs by call id.
  module AgentTimeCodex
    private

    def codex?(record, at)
      payload = record['payload']
      return false unless payload.is_a?(Hash)

      codex_event(payload, at)
      record['type'] == 'response_item' || %w[task_started task_complete].include?(payload['type'])
    end

    def codex_event(payload, at)
      case payload['type']
      when 'task_started' then codex_task(at)
      when 'task_complete', 'turn_aborted' then @open.clear
      when 'function_call', 'custom_tool_call', 'local_shell_call'
        open_call(payload['call_id'], payload['name'] || 'local_shell', codex_command(payload), at)
      when 'function_call_output', 'custom_tool_call_output' then close_call(payload['call_id'], at)
      end
    end

    # A new task ends any call the previous one left without an output, as when a killed session resumes.
    def codex_task(at)
      @open.clear
      start_turn(at) unless @before
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
  end
end
