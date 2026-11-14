# frozen_string_literal: true

require_relative '../repository_config/walkthrough_schema'
require_relative '../handoff/walkthrough'
require_relative '../publication/publishing'
require_relative '../publication/links'

module Shaka
  # Decides whether a PR owes a code walkthrough. One is due when the repository publishes one on every PR,
  # when the description records a request, or once this account has published one, since a walkthrough
  # left on an older head would misdescribe the change.
  class WalkthroughDue
    ALWAYS = 'always'
    REQUESTED = PublicationLinks::REQUESTED

    def initialize(github, publish:, reader: Handoff::Walkthrough.new(github))
      @github = github
      @publish = publish
      @reader = reader
    end

    def due? = @publish == ALWAYS || requested? || !@reader.revision.nil?

    # True while a due walkthrough does not yet explain this head.
    def missing_for?(head) = due? && @reader.revision != head

    # The request lives in the managed region, which only this account's description publication writes.
    def requested?
      body = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")['body'].to_s
      Publishing.managed_region(body.gsub("\r\n", "\n")).to_s.include?(REQUESTED)
    end
  end
end
