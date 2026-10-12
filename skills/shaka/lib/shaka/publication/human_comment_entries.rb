# frozen_string_literal: true

require_relative '../error'
require_relative '../walkthrough/history'

module Shaka
  # Finds the comments people wrote in a `shaka comments` result, and what answered each one.
  class HumanCommentEntries
    # unverified marks an author the comment reader could not trust, whose text it withheld.
    Entry = Struct.new(:kind, :id, :login, :url, :body, :state, :thread, :resolved, :unverified)
    # Reviews come first, then inline comments, then conversation comments, each in GitHub's order.
    KINDS = { 'review_summaries' => 'review_summary', 'inline_comments' => 'inline_comment',
              'issue_comments' => 'issue_comment' }.freeze
    VERDICTS = { 'APPROVED' => 'Approved', 'CHANGES_REQUESTED' => 'Requested changes' }.freeze
    # Agents post under a person's login, so the login cannot tell them apart. An agent post opens
    # with its identity line, a hidden `tool:purpose` marker, or the pointer of an archived
    # walkthrough. Any other hidden comment may open a person's own text.
    AGENT_OPENING = /\A(?:🤖 |<!-- ?[a-z][\w-]*:[\w.:-]+ ?-->|#{Regexp.escape(WalkthroughHistory::MARKER)})/i
    OPEN = ['Open', 'No reply', 'Changes requested'].freeze

    def initialize(packet)
      @kept = KINDS.flat_map { |key, kind| rows(packet, key).map { |row| entry(row, kind, false) } }
      # Without withheld text there is nothing for a person to read, and an unverified verdict is not shown.
      withheld = rows(packet, 'excluded_interactions').select { |row| row['body_withheld'] == true }
      @all = @kept + withheld.map { |row| entry(row, row['kind'], true) }
    end

    def humans = @all.select { |entry| human?(entry) }

    # The latest agent or bot post in the same inline thread, otherwise the latest agent post
    # linking the comment. A bot's summary that merely links a comment does not answer it.
    def answer(entry)
      return if entry.unverified

      thread_reply(entry) || @kept.reverse.find { |other| marked?(other) && !bot?(other) && links?(other, entry) }
    end

    # An inline thread has GitHub's own resolved state; anything else is open until something answers it.
    def status(entry)
      return 'Not read' if entry.unverified
      return entry.resolved ? 'Resolved' : 'Open' if entry.kind == 'inline_comment'

      verdict(entry) || (answer(entry) ? 'Replied' : 'No reply')
    end

    private

    def rows(packet, key)
      listed = packet[key]
      return listed if listed.is_a?(Array) && listed.all?(Hash)

      raise Error, "The comments file has no #{key} list; pass the output of `shaka comments --head SHA`."
    end

    def entry(row, kind, unverified)
      Entry.new(kind, row['id'], row['author'], row['url'], row['body'], row['state'], row['thread_id'],
                row['is_resolved'] == true, unverified)
    end

    # A pending review is its author's unsubmitted draft, and a review without text or a verdict
    # only carries its inline comments.
    def human?(entry)
      return false unless person?(entry) && entry.state != 'PENDING'

      entry.unverified || !entry.body.to_s.strip.empty? || VERDICTS.key?(entry.state)
    end

    def person?(entry) = entry.login.is_a?(String) && entry.id.is_a?(Integer) && !bot?(entry) && !marked?(entry)

    def verdict(entry)
      return 'Approved' if entry.state == 'APPROVED'
      return unless entry.state == 'CHANGES_REQUESTED'

      approved_later?(entry) ? 'Approved later' : 'Changes requested'
    end

    def bot?(entry) = entry.login.to_s.end_with?('[bot]')

    def marked?(entry) = entry.body.to_s.lstrip.match?(AGENT_OPENING)

    def thread_reply(entry)
      return unless entry.thread

      later(@kept, entry).select { |other| other.thread == entry.thread && (bot?(other) || marked?(other)) }
                         .max_by(&:id)
    end

    # GitHub serves a conversation comment under both /pull/ and /issues/, and `shaka reply` accepts either.
    def links?(other, entry)
      url = Regexp.escape(entry.url.to_s).sub(%r{/pull/(?=\d+\\#)}, '/(?:pull|issues)/')
      other.body.to_s.match?(/#{url}(?!\d)/)
    end

    def later(posts, entry) = posts.select { |other| other.id.is_a?(Integer) && other.id > entry.id }

    def approved_later?(entry)
      later(@kept, entry).any? do |other|
        other.kind == 'review_summary' && other.state == 'APPROVED' && other.login == entry.login
      end
    end
  end
end
