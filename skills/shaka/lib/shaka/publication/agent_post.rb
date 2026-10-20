# frozen_string_literal: true

require_relative '../walkthrough/history'

module Shaka
  # Tells an agent's post from a person's. Agents post under a person's login, so the login cannot
  # tell them apart. An agent post opens with its four-field identity line, a hidden `tool:purpose`
  # marker, or the pointer of an archived walkthrough. A person's own line may start with the emoji
  # or another hidden comment.
  module AgentPost
    IDENTITY = /🤖 [^\n·]+(?: · [^\n·]+){3}$/
    OPENING = /\A(?:#{IDENTITY}|<!-- ?[a-z][\w-]*:[\w.:-]+ ?-->|#{Regexp.escape(WalkthroughHistory::MARKER)})/

    def self.marked?(body) = body.to_s.lstrip.match?(OPENING)

    def self.bot?(login) = login.to_s.end_with?('[bot]')

    # GitHub serves a conversation comment under both /pull/ and /issues/, and `shaka reply` accepts either.
    def self.links?(body, url)
      pattern = Regexp.escape(url.to_s).sub(%r{/pull/(?=\d+\\#)}, '/(?:pull|issues)/')
      body.to_s.match?(/#{pattern}(?!\d)/)
    end
  end
end
