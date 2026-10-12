# frozen_string_literal: true

require_relative '../error'
require_relative '../public_comments/github_login'
require_relative 'comment_excerpt'
require_relative 'human_comment_entries'

module Shaka
  # Turns each comment a person wrote into the cells of its table row.
  class HumanCommentRows
    # reviewer is the login of a trusted person other than the PR author.
    Row = Struct.new(:reviewer, :open, :unverified, :cells)
    ANCHOR = /\A(?:issuecomment-|discussion_r|pullrequestreview-)\d+\z/
    IDENTITY_LINE = /^🤖 [^\n]*$/
    # The content key that maps a longer comment's URL to the agent's one-line summary of it.
    SUMMARIES = 'human_comment_summaries'

    # prefix is the pull request's URL up to the comment anchor; every link has to start with it.
    def initialize(entries, author:, prefix:, summaries:)
      @entries = entries
      @author = author
      @prefix = prefix
      @summaries = summaries
      @summarized = []
    end

    # Open comments lead, then those the agent could not read, and a reviewer's lead the author's.
    def call
      rows = @entries.humans.map { |entry| entry.unverified ? unverified(entry) : row(entry) }
      check_summaries
      rows.each_with_index.sort_by { |row, at| [urgency(row), row.reviewer ? 0 : 1, at] }.map(&:first)
    end

    private

    # The summaries have to match the longer comments exactly, so none is missing and none is stale.
    def check_summaries
      missing = @summarized - @summaries.keys
      unused = @summaries.keys - @summarized
      unless missing.empty?
        raise Error, "Publication #{SUMMARIES} needs a one-line summary for each longer human comment: " \
                     "#{missing.join(', ')}."
      end
      return if unused.empty?

      raise Error, "Publication #{SUMMARIES} names a comment the list does not summarize: #{unused.join(', ')}."
    end

    def urgency(row)
      return 0 if row.open

      row.unverified ? 1 : 2
    end

    # The comment is linked for the reader and never quoted, and the account's review verdict is
    # left out, because anyone can submit one.
    def unverified(entry)
      Row.new(nil, false, true,
              ["Unverified #{name(entry.login)}", link('Not read by the agent', entry.url), '—', 'Not read'])
    end

    def row(entry)
      status = @entries.status(entry)
      open = HumanCommentEntries::OPEN.include?(status)
      reviewer = entry.login.downcase unless entry.login.casecmp?(@author)
      Row.new(reviewer, open, false, ["#{reviewer ? '**Reviewer**' : 'Author'} #{name(entry.login)}", said(entry),
                                      response(entry), open ? "**#{status}**" : status])
    end

    # A profile link names the person without notifying them on every publication.
    def name(login)
      linkable = login.match?(PublicComments::GitHubLogin::PATTERN)
      linkable ? "[#{login}](https://github.com/#{login})" : CommentExcerpt.escape(login)
    end

    # A short comment is repeated whole. A longer one is already on the pull request, so the
    # agent's summary stands in for it, without quotation marks.
    def said(entry)
      link(CommentExcerpt.whole(entry.body) || summary(entry) || HumanCommentEntries::VERDICTS[entry.state] ||
           'Code or quoted text only', entry.url)
    end

    def summary(entry)
      return unless CommentExcerpt.prose?(entry.body)

      @summarized << entry.url
      CommentExcerpt.escape(@summaries.fetch(entry.url, ''))
    end

    def response(entry)
      answer = @entries.answer(entry)
      return '—' unless answer

      link(CommentExcerpt.opening(answer.body.to_s.split(IDENTITY_LINE, 2).last) || 'Reply', answer.url)
    end

    def link(label, url)
      return "[#{label}](#{url})" if url.is_a?(String) && url.start_with?(@prefix) &&
                                     url.delete_prefix(@prefix).match?(ANCHOR)

      raise Error, "The comments file lists a comment outside this pull request: #{url.inspect}."
    end
  end
end
