# frozen_string_literal: true

require_relative 'local_review_comment_test'
require_relative 'github_helper'

class LocalReviewCommitPublishTest < Minitest::Test
  include LocalReviewCommentFixture

  # A small renderer sufficient for the layout checks, plus keyed upserts like GitHub.
  class Timeline < LocalReviewPublishTest::FakeGitHub
    def markdown(body)
      summaries = body.scan(%r{<summary>.*?</summary>}).join("\n")
      details = body.scan('<details>').join + summaries + body.scan('</details>').join
      "#{details}<p>#{body.lines.last.strip}</p>"
    end

    def api(path)
      super
      { 'message' => path.end_with?(LocalReviewCommentFixture::HEAD) ? 'Clarify review documentation' : 'Add review publication' }
    end

    def reply(body:, key:)
      existing = replies.find { |item| item.first == key }
      existing ? existing[1] = body : super
      { 'id' => replies.index { |item| item.first == key } + 1 }
    end
  end

  def test_two_reviewers_per_commit_leave_two_idempotent_timeline_comments
    github = publish_loop
    assert_equal [EARLIER, HEAD].map { |sha| "local-review-#{sha}" }, github.replies.map(&:first)
    github.replies.each_with_index { |(_, body), index| assert_commit_entry(body, index) }
  end

  def test_merge_accepts_the_final_commit_attestation_from_a_timeline_comment
    evidence = Struct.new(:issue_comments) { def viewer_login = 'agent' }
    result = Shaka::MergeReviewEvidence.new(evidence.new(timeline_comments), required: 'meaningful_changes').call(HEAD)

    assert_equal 'current_head', result['basis']
  end

  def test_a_fix_commit_opens_with_findings_from_the_previous_triage
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD)
    github = Timeline.new
    rounds = [round(EARLIER, findings: [fixed]), clean(HEAD, 'openai/codex')]
    assert_equal 0, publish(github, 'rounds' => rounds).first

    body = github.replies.last.last
    assert_operator body.index('Missing test'), :<, body.index('| Round |')
    assert_includes body, 'F1'
    refute_includes body, 'Clarify review documentation'
    refute_includes body, '**Triage of [`bbbbbbb`'
  end

  def test_an_invalid_later_report_prevents_all_timeline_writes
    github = Timeline.new
    rounds = [clean(EARLIER, 'openai/codex'), round(report: report(EARLIER))]

    assert_equal 1, publish(github, 'rounds' => rounds).first
    assert_empty github.replies
  end

  def test_commit_subject_cannot_add_disclosures_or_a_heading
    github = Timeline.new
    def github.api(path)
      super.merge('message' => '<details># Subject `code`</details>')
    end
    assert_equal 0, publish(github, 'rounds' => [clean(HEAD, 'openai/codex')]).first

    body = github.replies.first.last
    assert_includes body, '&lt;details&gt;'
    assert_equal 1, body.scan('<details>').size
  end

  def test_commit_subject_is_literal_text_including_quotes_mentions_and_urls
    github = Timeline.new
    def github.api(path)
      super.merge('message' => "Don't notify @someone https://example.test")
    end
    assert_equal 0, publish(github, 'rounds' => [clean(HEAD, 'openai/codex')]).first

    assert_includes github.replies.first.last,
                    '<code>Don&#39;t notify @someone https://example.test</code>'
  end

  private

  def publish_loop
    github = Timeline.new
    rounds = [clean(EARLIER, 'openai/codex'), clean(EARLIER, 'anthropic/claude'),
              clean(HEAD, 'openai/codex'), clean(HEAD, 'anthropic/claude')]
    2.times do
      status, output, = publish(github, 'rounds' => rounds)
      assert_equal 0, status
      assert_includes JSON.parse(output).fetch('summary'), '**Total:** 4 rounds'
    end
    github
  end

  def assert_commit_entry(body, index)
    head = [EARLIER, HEAD][index]
    assert_equal 2, body.scan('<details>').size
    assert_includes body, index.zero? ? 'Add review publication' : 'Clarify review documentation'
    refute_includes body, '**Total:**'
    assert_equal "REVIEWED #{head} BY anthropic/claude EFFORT UNKNOWN FINDINGS 0", body.lines.last.strip
  end

  def timeline_comments
    publish_loop.replies.map do |key, body|
      { 'user' => { 'login' => 'agent' }, 'body' => "<!-- shaka:reply:#{key} -->\n#{body}",
        'html_url' => 'https://example.test/review' }
    end
  end

  def publish(github, content)
    Tempfile.create(['content-', '.json']) do |file|
      file.write(JSON.generate(content))
      file.close
      out, err = capture_io do
        @status = Shaka::LocalReview.run(['publish', 'o/r', '7', '--content-file', file.path], github:)
      end
      [@status, out, err]
    end
  end

  def clean(head, reviewer)
    round(head, reviewer:, findings: [], report: report(head, reviewer:, findings: 0))
  end
end

# The API client validates reply keys before any request; the timeline fake does not.
class LocalReviewCommitPublicationKeyTest < Minitest::Test
  include LocalReviewCommentFixture
  include GitHubHelper

  def test_generated_commit_key_passes_real_reply_validation
    comment = Shaka::LocalReviewCommitComment.new({ 'rounds' => [round] }, head: HEAD, subject: ->(_) { 'Subject' })
    body = comment.render
    posted = "<!-- shaka:reply:#{comment.key} -->\n#{body}"
    github = client(response({ 'id' => 1, 'number' => 42, 'body' => '' }),
                    response({ 'login' => 'agent' }), response([]), html_response('<table></table>'),
                    response({ 'id' => 9, 'body' => posted }))

    assert_equal 9, github.reply(body:, key: comment.key)['id']
  end
end
