# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Reopened here so the start comment stays outside publication/: it changes where a comment
  # goes, not how anything renders, and reuses Publishing's keyed lookup and checks.
  class GitHub
    # Posts a task's start comment on its issue.
    module StartComment
      def start_comment(body:, key:)
        mark = reply_mark(key)
        content = "#{mark}\n#{publishable(body)}"
        require_issue
        account = viewer
        existing = replies(nil).find { |comment| ours?(comment, mark, account) }
        verify_rendering(content)
        confirmed(write_reply(existing, content, nil), content)
      end

      private

      # A pull request is also an issue to GitHub, but it carries WIP Details instead.
      def require_issue
        return unless api("repos/#{@repository}/issues/#{@number}").key?('pull_request')

        raise Error, 'A start comment belongs on an issue; a pull request carries WIP Details instead.'
      end
    end

    include StartComment
  end
end
