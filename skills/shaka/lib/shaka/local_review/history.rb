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
      comments.select { |comment| attestation(comment['body'])[1] == head && active?(comment) }
              .max_by { |comment| order(comment) }
    end

    # A restored head needs its previously archived report republished before it can be current.
    def active?(comment) = !comment['body'].match?(/^#{Regexp.escape(MARKER)} /o)

    def owned?(comment) = super && !attestation(comment['body'].to_s).nil?

    def earlier?(comment, latest)
      attestation(comment['body'])[1] != attestation(latest['body'])[1]
    end

    # Returning to a reviewed head can make its comment older than the existing pointer.
    def keep_pointer?(previous, latest) = previous == latest

    def attestation(body) = body.match(ATTESTATION)

    def footer(content) = "\n#{attestation(content)[0].strip}\n"
  end
end
