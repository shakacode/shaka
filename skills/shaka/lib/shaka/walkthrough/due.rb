# frozen_string_literal: true

require_relative '../repository_config/walkthrough_schema'
require_relative '../handoff/walkthrough'

module Shaka
  # Decides whether a PR owes a code walkthrough. One is due when the repository publishes one on every PR,
  # when this account recorded a request, or once this account has published one, since a walkthrough
  # left on an older head would misdescribe the change.
  class WalkthroughDue
    ALWAYS = 'always'
    # The agent records a request with `reply --key walkthrough-request`, which writes this marker first.
    REQUEST_MARKER = '<!-- shaka:reply:walkthrough-request -->'

    def initialize(github, publish:, reader: Handoff::Walkthrough.new(github))
      @github = github
      @publish = publish
      @reader = reader
    end

    def due? = @publish == ALWAYS || @reader.published? || requested?

    # True while a due walkthrough does not yet explain this head.
    def missing_for?(head) = due? && @reader.revision != head

    # Only this account's comment counts: a PR body, or anyone else's comment, can be edited by
    # people the gate must not trust, and a later description refresh would drop a request kept there.
    def requested?
      account = @reader.account
      Array(@github.issue_comments).compact.any? do |comment|
        comment.dig('user', 'login') == account && comment['body'].to_s.start_with?(REQUEST_MARKER)
      end
    end
  end
end
