# frozen_string_literal: true

require 'securerandom'
require_relative '../error'
require_relative '../publication/evidence_history'
require_relative '../publication/text'
require_relative 'captures'

module Shaka
  module UiCheck
    # Publishes one UI check for the PR head, then folds this account's earlier ones under it.
    class Publisher
      MARKER = /^<!-- shaka:ui-check-(\h{40})-(\h{8}) -->$/

      def initialize(github, nonce: SecureRandom.hex(4))
        @github = github
        @nonce = nonce
      end

      def call(head:, content:)
        verify_head(head)
        captures = PublicationText.list(content['captures'], 'captures')
        Captures.paths(captures)
        earlier = open_checks
        body = body(head, content)
        check_carried(earlier, body, PublicationText.list(content['retire'], 'retire'))
        @github.verify_rendering(body)
        @github.post_comment(body, attachments: captures)
        published = confirm_uploads(find_published(head), body, captures)
        report(published, earlier)
      end

      private

      def verify_head(head)
        raise Error, 'Expected a full commit SHA.' unless head.is_a?(String) && head.match?(/\A\h{40}\z/)

        pr = @github.snapshot
        raise Error, 'Pull request is not open at the expected head.' unless
          pr['state'] == 'OPEN' && pr['headRefOid'] == head
      end

      def body(head, content)
        commit = "https://github.com/#{@github.repository}/pull/#{@github.number}/commits/#{head}"
        "#{PublicationText.publisher_identity(content)}\n\n<!-- shaka:ui-check-#{head}-#{@nonce} -->\n" \
          "# Verification for [`#{head[0, 7]}`](#{commit})\n\n" \
          "#{PublicationText.required(content['body'], 'body').strip}\n"
      end

      # Folded checks already point at a newer one, so only open checks can still hold evidence.
      def open_checks
        @account = @github.viewer_login
        raise Error, 'Authenticated GitHub login is unavailable.' unless @account.is_a?(String) && !@account.empty?

        @github.issue_comments.select { |comment| own_check?(comment) && !folded?(comment['body']) }
      end

      def folded?(body) = body.sub(EvidenceHistory::KEY, '').start_with?("#{EvidenceHistory::MARKER} ")

      def own_check?(comment)
        comment.dig('user', 'login') == @account && comment['body'].to_s.start_with?('🤖 ') &&
          comment['body'].to_s.match?(MARKER)
      end

      def check_carried(earlier, body, retired)
        missing = Captures.missing(earlier.flat_map { |comment| Captures.urls(comment['body']) }.uniq, body, retired)
        return if missing.empty?

        raise Error, 'An earlier UI check shows captures this one leaves out. Embed each one for an unchanged ' \
                     "view, or retire it as replaced: #{missing.join(', ')}"
      end

      def find_published(head)
        found = @github.issue_comments.select do |comment|
          own_check?(comment) && comment['body'].match(MARKER)&.captures == [head, @nonce]
        end
        raise Error, 'The posted UI check is missing from the comment listing; inspect the PR.' unless found.one?

        found.first
      end

      # gh rewrites a referenced file to its upload and appends the rest, so each capture adds a URL.
      def confirm_uploads(published, submitted, captures)
        added = Captures.urls(published['body']) - Captures.urls(submitted)
        local = Captures.paths(captures).select { |path| published['body'].include?("](#{path})") }
        return published if added.length >= captures.length && local.empty?

        raise Error, "UI check #{published['html_url']} is missing uploaded captures; inspect and edit it."
      end

      def report(published, earlier)
        ids = earlier.map { |comment| comment['id'] }
        folded = ids.empty? ? { 'collapsed' => [], 'unavailable' => [] } : fold(ids, published['id'])
        { 'comment' => published['html_url'], 'id' => published['id'] }.merge(folded)
      end

      def fold(ids, current) = EvidenceHistory.new(@github).collapse(ids, current:)
    end
  end
end
