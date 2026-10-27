# frozen_string_literal: true

require_relative '../publication/publication'

module Shaka
  # The description's overflow comment has to name this head before handoff is clear.
  module HandoffOverflow
    private

    def overflow_fact(live)
      pull = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")
      recheck_head(pull.dig('head', 'sha'), live)
      comment = overflow_comment
      message = DescriptionOverflow.issue(pull['body'], comment, live)
      return owe('usage details comment', message) if message
      return "usage details #{live[0, Handoff::SHORT]}" if DescriptionOverflow.tracked?(pull['body'], comment)

      nil
    rescue Error => e
      owe('usage details comment unread', e.message)
    end

    def overflow_comment
      login = @github.viewer_login
      found = Array(@github.issue_comments).find { |comment| DescriptionOverflow.ours?(comment, login) }
      found && found['body']
    end
  end
end
