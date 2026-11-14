# frozen_string_literal: true

require_relative '../usage/codex_usage'
require_relative '../publication/task_timing'

module Shaka
  # The caller selects the original turn. The transcript contributes only its timestamp.
  module CodexTaskStart
    KEY = 'codex_task_start'
    UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/

    module_function

    def resolve(content, opened: Time.now.utc, environment: ENV, now: Time.now.utc)
      return [content, nil] unless content.key?(KEY)

      selected = content.fetch(KEY)
      described = content.reject { |key, _| key == KEY }
      return [described, nil] unless described['task_started_at'].nil?

      thread, turn = selection(selected)
      file = CodexUsage.session_file(thread, environment:)
      started = turn_start(file, turn, now) if file
      return [described, 'Selected Codex turn timestamp unavailable.'] unless started
      return [described, 'Selected Codex turn is after PR opening.'] if started > opened

      [described.merge('task_started_at' => started.iso8601(9)), nil]
    end

    def selection(selected)
      ids = selected.values_at('thread_id', 'turn_id') if selected.is_a?(Hash)
      return ids if ids&.all? { |id| id.is_a?(String) && UUID.match?(id) }

      raise Error, 'Publication codex_task_start requires UUIDs for thread_id and turn_id.'
    end

    def turn_start(file, turn, now)
      matches = File.foreach(file, encoding: 'UTF-8').filter_map do |line|
        start_event(line, turn) if line.include?('task_started')
      end
      TaskTiming.timestamp(matches.first.fetch('timestamp', nil), now) if matches.one?
    rescue SystemCallError, EncodingError
      nil
    end

    def start_event(line, turn)
      record = JSON.parse(line)
      return unless record.is_a?(Hash) && record['type'] == 'event_msg'

      payload = record['payload']
      record if payload.is_a?(Hash) && payload['type'] == 'task_started' && payload['turn_id'] == turn
    rescue JSON::ParserError, EncodingError
      nil
    end
  end
end
