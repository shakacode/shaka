# frozen_string_literal: true

require_relative '../publication/feature_guard'

module Shaka
  # Keeps a blocked checkpoint visible across normal description refreshes.
  class PostImplementationMergeWarning
    OPEN = '<!-- shaka:merge-warning:begin -->'
    CLOSE = '<!-- shaka:merge-warning:end -->'
    DRAFT = <<~GRAPHQL
      mutation($id: ID!) {
        convertPullRequestToDraft(input: {pullRequestId: $id}) {
          pullRequest { id isDraft headRefOid }
        }
      }
    GRAPHQL

    def initialize(github)
      @github = github
      @path = "repos/#{github.repository}/pulls/#{github.number}"
    end

    def call(head:, publication:, published:)
      # Opting out of a review does not settle a previously published concern.
      return { 'state' => 'unchanged' } if publication.state == 'opted_out'

      current = @github.api(@path)
      verify_head(current, head)
      return { 'state' => 'superseded' } unless latest?(published)

      blocked = publication.state != 'ready'
      make_draft(head) if blocked
      update(current, head, blocked, publication.summary, published)
      { 'state' => blocked ? 'blocked' : 'cleared', 'head' => head }
    end

    private

    def update(current, head, blocked, summary, published)
      body = current['body'].to_s
      remaining = without_warning(body)
      updated = blocked ? "#{warning(head, summary, published)}#{remaining}" : remaining
      raise Error, 'Merge warning exceeds GitHub description length.' if updated.length > 65_536

      @github.verify_rendering(updated) unless updated == body
      FeaturePublication.unchanged!(@github, body, current)
      write(updated) unless updated == body
    end

    def latest?(published)
      account = @github.viewer_login
      latest = @github.issue_comments.reverse.find do |comment|
        comment.dig('user', 'login') == account && comment['body'].to_s.match?(PostImplementationHistory::KEY)
      end
      raise Error, 'Published checkpoint is absent from the comment listing; retry publication.' unless latest

      latest['id'] == published['id']
    end

    def verify_head(pull, head)
      return if pull['state'] == 'open' && pull.dig('head', 'sha') == head

      raise Error, 'Merge warning is not for the live open PR head; the checkpoint comment remains published.'
    end

    def without_warning(body)
      opens = body.scan(OPEN).size
      closes = body.scan(CLOSE).size
      return body if opens.zero? && closes.zero?

      unless opens == 1 && closes == 1 && body.index(OPEN) < body.index(CLOSE)
        raise Error, 'Merge warning markers are ambiguous or malformed; repair them before retrying.'
      end

      prefix, rest = body.split(OPEN, 2)
      suffix = rest.split(CLOSE, 2).last.delete_prefix("\n\n")
      "#{prefix}#{suffix}"
    end

    def warning(head, summary, published)
      url = PublicationText.single_line(published['html_url'], 'checkpoint URL')
      raise Error, 'Checkpoint URL must use HTTPS.' unless url.match?(%r{\Ahttps://[^\s]+\z})

      reason = summary.lines.map do |line|
        "> #{line.chomp.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')}"
      end.join("\n")
      "#{OPEN}\n> **⛔ Do not merge — post-implementation checkpoint blocked.**\n>\n#{reason}\n>\n" \
        '> Task owner: resolve the linked concerns and publish a new checkpoint for the current head. ' \
        "Keep this PR in draft until all required gates pass.\n>\n" \
        "> [Blocking report](#{url}) · Head `#{head}`. Passing technical checks does not resolve this blocker.\n" \
        "#{CLOSE}\n\n"
    end

    def make_draft(head)
      pull = @github.snapshot
      raise Error, 'PR changed before draft conversion; retry the checkpoint publication.' unless
        pull.values_at('state', 'headRefOid') == ['OPEN', head]
      return if pull['isDraft']

      changed = @github.graphql(DRAFT, id: pull.fetch('id')).dig('convertPullRequestToDraft', 'pullRequest')
      return if changed && changed.values_at('id', 'isDraft', 'headRefOid') == [pull['id'], true, head]

      raise Error, 'Draft conversion was not confirmed at the checkpoint head; inspect the PR before retrying.'
    end

    def write(body)
      stored = @github.api(@path, method: 'PATCH', fields: { body: })
      return if stored['body'] == body

      raise Error, 'Stored merge warning does not match the submitted description; inspect the PR before retrying.'
    end
  end
end
