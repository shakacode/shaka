# frozen_string_literal: true

module Shaka
  # Rewrites an OpenCode 2 session export (observed on 2.0.32) into the 1.x layout the
  # reader parses. Version 2 wraps the session in `data`, puts message fields at the top
  # level, nests the model, and drops parentID, so a response's turn is the nearest
  # earlier user message. Other documents pass through unchanged.
  module OpencodeV2Layout
    module_function

    def normalize(document)
      data = document['data'] if document.is_a?(Hash) && !document.key?('messages')
      return document unless data.is_a?(Hash)

      messages = data['messages']
      return { 'info' => data['info'] } unless messages.is_a?(Array)

      { 'info' => data['info'], 'messages' => with_turns(messages) }
    end

    def with_turns(messages)
      turn = nil
      messages.map do |message|
        next message unless message.is_a?(Hash)

        turn = message['id'] if message['type'] == 'user'
        { 'info' => info(message, turn) }
      end
    end

    def info(message, turn)
      model = message['model'].is_a?(Hash) ? message['model'] : {}
      { 'role' => message['type'], 'id' => message['id'], 'parentID' => turn, 'time' => message['time'],
        'tokens' => message['tokens'], 'providerID' => model['providerID'], 'modelID' => model['id'],
        'variant' => model['variant'] }
    end
  end
end
