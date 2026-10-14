# frozen_string_literal: true

require_relative 'loop_comment'
require_relative 'history'

module Shaka
  # Preflights every comment, then upserts the main comment and any continuations. A retry resumes
  # partial publication.
  class LocalReviewPublisher
    def initialize(content, github, repository)
      @content = content
      @github = github
      @repository = repository
      @commits = {}
    end

    def publish
      summary = LocalReviewComment.new(@content).loop_summary
      parts = LocalReviewLoopComment.new(@content, repository: @repository,
                                                   usage_url: "https://github.com/#{@repository}/pull/#{@github.number}",
                                                   published: ->(sha) { !commit(sha).nil? },
                                                   subject: ->(sha) { subject(sha) }).parts
      parts.each { |part| part.check_rendering!(@github.verify_rendering(part.body)) }
      results = parts.map { |part| @github.reply(body: part.body, key: part.key) }
      { 'comments' => results, 'summary' => summary, 'cleanup' => cleanup(results) }
    end

    private

    # Comments from the per-commit publisher that this ledger covers are retired with the rest.
    def cleanup(results)
      ids = results.map { |result| result.fetch('id') } + per_commit_comments
      LocalReviewHistory.new(@github, ids:).collapse
    end

    def per_commit_comments
      marks = @content.fetch('rounds').map { |round| "<!-- shaka:reply:local-review-#{round.fetch('head')} -->\n" }
      @github.issue_comments.filter_map do |comment|
        comment['id'] if marks.any? { |mark| comment['body'].to_s.start_with?(mark) }
      end
    rescue Error
      []
    end

    # Cache both the subject and existence; a 404 names an unpushed or replaced commit.
    # Other failures stop publication before any comment is written.
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
