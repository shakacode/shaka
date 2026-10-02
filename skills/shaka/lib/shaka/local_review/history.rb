# frozen_string_literal: true

require_relative '../publication/comment_history'

module Shaka
  # Earlier reports retain their findings and their closing merge attestation.
  # A different reviewed commit is history, not proof that any concern was resolved.
  class LocalReviewHistory < CommentHistory
    MARKER = 'Earlier review — findings are not automatically resolved. Latest local review:'
    KEY = /\A<!-- shaka:reply:(?:local-adversarial-review|local-review-[0-9a-f]{40}) -->\n/
    SUMMARY = 'Earlier local review'
    ATTESTATION = %r{^REVIEWED ([0-9a-f]{40}) BY [\w-]+/[\w.-]+ EFFORT \S+ FINDINGS \d+\s*\z}

    private

    def latest_comment(comments)
      head = @github.api("repos/#{@github.repository}/pulls/#{@github.number}").dig('head', 'sha')
      latest = comments.select { |comment| attestation(comment['body'])[1] == head }
                       .max_by { |comment| order(comment) }
      latest || raise(Error, 'No owned local review covers the current PR head; history was left intact.')
    end

    def owned?(comment) = super && !attestation(comment['body'].to_s).nil?

    def earlier?(comment, latest)
      super && attestation(comment['body'])[1] != attestation(latest['body'])[1]
    end

    def attestation(body) = body.match(ATTESTATION)

    def footer(content) = "\n#{attestation(content)[0].strip}\n"
  end
end
