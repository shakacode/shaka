# frozen_string_literal: true

require_relative 'comment'
require_relative 'history'

module Shaka
  # Confirm the new report before attempting any older-comment edits.
  class LocalReviewPublication
    def initialize(github, content, repository)
      @github = github
      @content = content
      @repository = repository
    end

    def publish
      comment = LocalReviewComment.new(@content, repository: @repository, published: method(:on_github?))
      body = comment.render
      comment.check_rendering!(@github.markdown(body))
      published = @github.reply(body:, key: LocalReviewComment::KEY)
      published.merge('earlier_reviews' => LocalReviewHistory.new(@github).collapse(published))
    end

    private

    # A rebase can replace an unpushed commit; an outage cannot establish its absence.
    def on_github?(sha)
      @github.api("repos/#{@repository}/git/commits/#{sha}")
      true
    rescue Shaka::Error => e
      raise unless e.http_status == 404

      false
    end
  end
end
