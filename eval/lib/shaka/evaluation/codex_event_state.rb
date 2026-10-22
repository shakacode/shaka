# frozen_string_literal: true

module Shaka
  module Evaluation
    # Lifecycle checks do not interpret command text or grant terminal acceptance.
    class CodexEventState
      ITEM_EVENTS = %w[item.started item.updated item.completed].freeze

      def initialize
        @phase = :new
        @items = {}
      end

      def receive(observation)
        event = observation.fetch('native')
        type = event.fetch('type')
        case type
        when 'thread.started' then start_thread(event)
        when 'turn.started' then transition(:thread, :turn)
        when 'turn.completed', 'turn.failed' then end_turn(observation, type)
        when 'error' then @error = true
        when *ITEM_EVENTS then item(observation)
        else unavailable
        end
      end

      def result(exit_code)
        status = status(exit_code)
        { 'thread_id' => @thread, 'native_status' => status,
          'terminal' => status == 'completed' ? terminal : nil,
          'turn_ended_at' => @ended&.fetch('received_at') }
      end

      private

      def start_thread(event)
        id = event.fetch('thread_id')
        unavailable unless id.is_a?(String) && !id.strip.empty?
        transition(:new, :thread)
        @thread = id
      end

      def transition(expected, following)
        unavailable unless @phase == expected
        @phase = following
      end

      def end_turn(observation, type)
        transition(:turn, type == 'turn.completed' ? :completed : :failed)
        @ended = observation
      end

      def item(observation)
        unavailable unless @phase == :turn
        event = observation.fetch('native')
        value = event.fetch('item')
        record_item(value, event.fetch('type'))
        @message = observation if agent_message?(event, value)
      end

      def record_item(value, stage)
        id, type = value.values_at('id', 'type')
        unavailable unless [id, type].all? { it.is_a?(String) && !it.strip.empty? }
        previous = @items[id]
        unavailable if previous && (previous.first != type || previous.last == 'item.completed' ||
                                    stage == 'item.started')
        @items[id] = [type, stage]
      end

      def agent_message?(event, value)
        return false unless event.fetch('type') == 'item.completed' && value.fetch('type') == 'agent_message'

        unavailable unless value.fetch('text').is_a?(String)
        true
      end

      def status(exit_code)
        return 'failed' if @error || @phase == :failed
        return 'incomplete' if exit_code.nil?
        return 'failed' unless exit_code.zero?

        @phase == :completed ? 'completed' : 'incomplete'
      end

      def terminal
        return unless @message

        value = @message.fetch('native').fetch('item')
        return if value.fetch('text').strip.empty?

        { 'type' => 'assistant_terminal', 'text' => value.fetch('text'),
          'native_item_id' => value.fetch('id'), 'received_at' => @message.fetch('received_at') }
      end

      def unavailable = raise(IOError, 'Native Codex event order unavailable')
    end
  end
end
