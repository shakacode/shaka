# frozen_string_literal: true

require 'open3'

module Shaka
  # OpenCode 2 support for the OpenCode reader, observed on 2.0.32.
  module OpencodeV2
    module_function

    # Version 2 removed `opencode export` and serves the session through its API instead.
    # Choosing by the installed version sends neither release a command it lacks; an
    # unreadable version keeps the 1.x command.
    def export_command(session)
      major = installed_major
      major && major >= 2 ? ['api', 'get', "/api/experimental/session/#{session}/export"] : ['export', session]
    end

    def installed_major
      output, status = Open3.capture2('opencode', '--version', err: File::NULL)
      output[/(\d+)\.\d+/, 1]&.to_i if status.success?
    end

    # Rewrites a version 2 export into the 1.x layout the reader parses. Version 2 wraps
    # the session in `data`, puts message fields at the top level, nests the model, and
    # drops parentID, so a response's turn is the nearest earlier user message. Other
    # documents pass through unchanged.
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

    # A compaction that reports tokens is a billed model call, as 1.x recorded it with an
    # assistant message, so it counts as a response.
    def info(message, turn)
      model = message['model'].is_a?(Hash) ? message['model'] : {}
      billed = message['type'] == 'compaction' && message['tokens'].is_a?(Hash)
      { 'role' => billed ? 'assistant' : message['type'], 'id' => message['id'], 'parentID' => turn,
        'time' => message['time'],
        'tokens' => message['tokens'], 'providerID' => model['providerID'], 'modelID' => model['id'],
        'variant' => model['variant'] }
    end
  end
end
