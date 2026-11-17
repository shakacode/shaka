# frozen_string_literal: true

require 'securerandom'
require_relative '../error'
require_relative '../publication/evidence_history'
require_relative '../publication/text'
require_relative 'captures'
require_relative 'history'

module Shaka
  module UiCheck
    # Publishes one UI check for the PR head, carrying earlier captures it leaves out under a
    # collapsed history, then folds this account's earlier checks under it.
    class Publisher
      MARKER = /^<!-- shaka:ui-check-(\h{40})-(\h{8}) -->$/
      LIMIT = 65_536
      UPLOAD_ROOM = 100

      def initialize(github, nonce: SecureRandom.hex(4))
        @github = github
        @nonce = nonce
      end

      def call(head:, content:)
        verify_head(head)
        captures = PublicationText.list(content['captures'], 'captures')
        Captures.paths(captures)
        earlier = open_checks(PublicationText.list(content['earlier'], 'earlier'))
        body = body(head, content, earlier, PublicationText.list(content['retire'], 'retire'))
        check_length(body, captures)
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

      def body(head, content, earlier, retired)
        note = PublicationText.required(content['body'], 'body').strip
        raise Error, 'UI check body must not contain Shaka history markers; earlier evidence is carried for you.' if
          History.reserved?(note)

        "#{PublicationText.publisher_identity(content)}\n\n<!-- shaka:ui-check-#{head}-#{@nonce} -->\n" \
          "# Verification for [`#{head[0, 7]}`](#{commit_url(head)})\n\n#{note}\n" \
          "#{history(earlier, note, retired, head)}"
      end

      def commit_url(sha) = "https://github.com/#{@github.repository}/pull/#{@github.number}/commits/#{sha}"

      # The new check's own note decides what it shows; anything else an open earlier check
      # shows is carried with that check's revision, unless the agent retires it.
      def history(earlier, note, retired, head)
        checks = earlier.map do |comment|
          body = comment['body'].sub(EvidenceHistory::KEY, '')
          { revision: body[MARKER, 1], source: comment['html_url'], body: body.sub(/#{MARKER}\n?/o, '') }
        end
        blocks = History.carry(checks, shown: Captures.urls(note), retired:, head:)
        History.render(blocks, head:, commit_url: method(:commit_url))
      end

      # gh rewrites or appends each capture as an image link to its upload, so leave room for it.
      def check_length(body, captures)
        length = body.length + captures.sum { |capture| capture.length + UPLOAD_ROOM }
        return if length <= LIMIT

        raise Error, "The UI check would be about #{length} characters, over GitHub's limit of #{LIMIT}. Shorten " \
                     'the note, or retire every remaining capture of a carried check so it is no longer carried.'
      end

      # Folded checks already point at a newer one, so only open checks can still hold evidence.
      # Checks posted before this command carry no marker, so the agent names them.
      def open_checks(selected)
        @account = @github.viewer_login
        raise Error, 'Authenticated GitHub login is unavailable.' unless @account.is_a?(String) && !@account.empty?

        comments = unix_comments
        named = selected.map { |id| named_check(comments, id) }
        (comments.select { |comment| own_check?(comment) } | named).reject { |comment| folded?(comment['body']) }
      end

      # A comment edited on the web can come back with CRLF line endings.
      def unix_comments
        @github.issue_comments.each { |comment| comment['body'] = comment['body'].to_s.gsub("\r\n", "\n") }
      end

      def named_check(comments, id)
        comment = comments.find { |row| row['id'] == id }
        return comment if comment && own?(comment)

        raise Error, "Earlier UI check #{id} is not this account's AI-authored comment on this PR."
      end

      def own?(comment) = comment.dig('user', 'login') == @account && comment['body'].to_s.start_with?('🤖 ')

      def folded?(body) = body.sub(EvidenceHistory::KEY, '').start_with?("#{EvidenceHistory::MARKER} ")

      def own_check?(comment) = own?(comment) && comment['body'].to_s.match?(MARKER)

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
        local = captures.map { |capture| capture.split('#', 2).first }
                        .select { |path| published['body'].include?("](#{path})") }
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
