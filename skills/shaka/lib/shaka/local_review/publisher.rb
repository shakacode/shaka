# frozen_string_literal: true

require_relative 'commit_comment'

module Shaka
  # Preflights every comment, then upserts in ledger order. A retry resumes partial publication.
  class LocalReviewPublisher
    def initialize(content, github, repository)
      @content = content
      @github = github
      @repository = repository
      @commits = {}
    end

    def publish
      summary = LocalReviewComment.new(@content).loop_summary
      ready = @content.fetch('rounds').map { |round| round.fetch('head') }.uniq.map { |head| prepare(head) }
      results = ready.map { |key, body| @github.reply(body:, key:) }
      { 'comments' => results, 'summary' => summary }
    end

    private

    def prepare(head)
      comment = LocalReviewCommitComment.new(@content, head:, repository: @repository,
                                                       published: ->(sha) { !commit(sha).nil? },
                                                       subject: ->(sha) { subject(sha) })
      body = comment.render
      size = "<!-- shaka:reply:#{comment.key} -->\n#{body}".length
      raise Error, "Review comment for #{head[0, 7]} exceeds GitHub’s 65536-character limit; shorten its reports." if
        size > 65_536

      comment.check_rendering!(@github.markdown(body))
      [comment.key, body]
    end

    # Cache both the subject and existence; a 404 names an unpushed or replaced commit.
    # Other failures stop publication before any timeline entry is written.
    def commit(sha)
      @commits.fetch(sha) do
        @commits[sha] = @github.api("repos/#{@repository}/git/commits/#{sha}")
      rescue Shaka::Error => e
        raise unless e.http_status == 404

        @commits[sha] = nil
      end
    end

    def subject(sha)
      text = commit(sha)&.fetch('message', nil).to_s.lines.first.to_s.strip
      return 'Commit subject unavailable.' if text.empty?

      # A commit subject is data, not Markdown that may hide the generated review layout.
      "<code>#{text.each_char.map { |char| "&##{char.ord};" }.join}</code>"
    end
  end
end
