# frozen_string_literal: true

require_relative 'error'
require_relative 'public_comments/bounded_list'

module Shaka
  # Collapses earlier Code Walkthrough reviews after a new one is confirmed.
  #
  # Only a COMMENT review by the authenticated author is rewritten. The previous
  # body stays in the details block, including any later human edit of that text.
  # A failure here is reported on the new review and does not undo its publication.
  class WalkthroughHistory
    MARKER = 'Superseded — read the current walkthrough:'
    POINTER = /\A#{Regexp.escape(MARKER)} (\S+)/
    HEADING = /^# Code Walkthrough$/
    FOOTER = /_Walkthrough for commit `([0-9a-f]{40})`\. This is a COMMENT, not an approval\._/
    ATTESTATION = /^REVIEWED [0-9a-f]{40} BY \S/
    UPDATE = <<~GRAPHQL
      mutation($id: ID!, $body: String!) {
        updatePullRequestReview(input: {pullRequestReviewId: $id, body: $body}) {
          pullRequestReview { body }
        }
      }
    GRAPHQL

    def initialize(github) = @github = github

    def collapse(published)
      report = fresh_report
      url = review_url(published.fetch('id'))
      reviews = earlier_walkthroughs(published['id'])
      return report if reviews.empty?

      account = authenticated_login
      reviews.each { |review| fold_one(review, url, account, report) }
      report
    rescue Error => e
      report['unavailable'] << e.message
      report
    end

    private

    def fresh_report = { 'collapsed' => [], 'left_intact' => [], 'unavailable' => [] }

    def earlier_walkthroughs(current_id)
      list_reviews.select { |review| collapse_candidate?(review, current_id) }
    end

    def collapse_candidate?(review, current_id)
      review['id'] != current_id && review['state'] == 'COMMENTED' && walkthrough_body?(review['body'].to_s)
    end

    def walkthrough_body?(body)
      return false if body.match?(ATTESTATION)

      collapsed?(body) || (body.match?(HEADING) && body.match?(FOOTER))
    end

    def collapsed?(body) = body.start_with?("#{MARKER} ")

    def fold_one(review, url, account, report)
      return report['left_intact'] << review['id'] unless review.dig('user', 'login') == account

      apply_revision(review, revised_body(review['body'].to_s, url), report)
    rescue Error => e
      report['unavailable'] << "Review #{review['id']}: #{e.message}"
    end

    def apply_revision(review, revised, report)
      return if revised.nil? || revised == review['body']

      replace_review(review, revised)
      report['collapsed'] << review['id']
    end

    def revised_body(body, url)
      return retarget(body, url) if collapsed?(body)

      wrap(body, url)
    end

    def retarget(body, url)
      return if body[POINTER, 1] == url

      body.sub(POINTER, "#{MARKER} #{url}")
    end

    def wrap(body, url)
      sha = body[FOOTER, 1]
      summary = sha ? "Walkthrough for commit `#{sha}`" : 'Earlier code walkthrough'
      "#{MARKER} #{url}\n\n<details>\n<summary>#{summary}</summary>\n\n#{body.rstrip}\n\n</details>\n"
    end

    def replace_review(review, body)
      node = review['node_id']
      raise Error, 'Review has no GraphQL id.' unless node.is_a?(String) && !node.empty?

      @github.verify_rendering(body)
      @github.graphql(UPDATE, { id: node, body: body })
      stored = @github.review(review['id'])
      return if stored.is_a?(Hash) && stored['body'] == body

      raise Error, 'Stored review body did not match the collapsed walkthrough.'
    end

    def list_reviews
      path = "repos/#{@github.repository}/pulls/#{@github.number}/reviews"
      PublicComments::BoundedList.new(@github, max_pages: 5, label: 'Review listing').call(path)
    end

    def authenticated_login
      account = @github.api('user')['login']
      return account if account.is_a?(String) && !account.empty?

      raise Error, 'Authenticated GitHub login is unavailable.'
    end

    def review_url(id)
      "https://github.com/#{@github.repository}/pull/#{@github.number}#pullrequestreview-#{id}"
    end
  end
end
