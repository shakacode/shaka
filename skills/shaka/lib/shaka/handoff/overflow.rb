# frozen_string_literal: true

require_relative '../publication/publication'

module Shaka
  # The description's overflow comment has to name this head before handoff is clear.
  module HandoffOverflow
    private

    # Only a description that says its sections were moved needs the comment read.
    def overflow_fact(live)
      return unless DescriptionOverflow.moved?(pull['body'])

      comment = DescriptionOverflow.find(@github)
      message = DescriptionOverflow.issue(pull['body'], comment && comment['body'], live)
      message ? owe('usage details comment', message) : "usage details #{live[0, Handoff::SHORT]}"
    rescue Error => e
      owe('usage details comment unread', e.message)
    end
  end
end
