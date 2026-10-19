# frozen_string_literal: true

require 'json'
require 'time'

module Shaka
  class UpdateCheck
    # Main moves several times a day, so the update notice waits until an update is worth interrupting a chat.
    module Notice
      COMMITS = 3
      SECONDS = 24 * 60 * 60
      # Claude Code adds a SessionStart hook's plain-text output to the new chat, but not a JSON answer.
      SESSION_START = '--session-start'
      ACTIONABLE = %w[available drift].freeze
      GUIDANCE = "Shaka suggests updating once it is #{COMMITS} commits or a day behind.".freeze

      # A usable count below the threshold waits unless the oldest missing commit is a day old.
      def self.wait?(ahead_by, oldest, now: Time.now)
        return false unless ahead_by.is_a?(Integer) && ahead_by.positive? && ahead_by < COMMITS

        now - Time.iso8601(oldest.to_s) < SECONDS
      rescue ArgumentError
        true
      end

      # The text to print. At chat start only an answer that needs action is worth the chat's attention.
      def self.render(result, arguments)
        return "#{JSON.generate(result)}\n" if arguments.empty?
        return '' unless ACTIONABLE.include?(result['status'])

        "Shaka update check (#{result['status']}): #{result['guidance']}\n"
      end
    end
  end
end
