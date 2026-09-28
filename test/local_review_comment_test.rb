# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tempfile'
require 'shaka/local_review'
require 'shaka/merge_review_evidence'

# Builds review rounds whose reports close with a real attestation.
module LocalReviewCommentFixture
  HEAD = 'a' * 40
  EARLIER = 'b' * 40
  TRUSTED = 'c' * 40

  private

  def report(head = HEAD, body: "1. [P2] Missing test.\n", reviewer: 'openai/codex', findings: 1)
    file = Tempfile.create(['report-', '.md'])
    file.write("#{body}\nREVIEWED #{head} BY #{reviewer} EFFORT UNKNOWN FINDINGS #{findings}\n")
    file.close
    (@reports ||= []) << file.path
    file.path
  end

  def round(head = HEAD, **changes)
    { 'head' => head, 'reviewer' => 'openai/codex', 'report' => report(head), 'model' => 'gpt-5.5',
      'prompt_source' => 'Shaka default', 'criteria_ref' => TRUSTED,
      'tokens' => '41,200' }.merge(changes.transform_keys(&:to_s))
  end

  def render(content) = Shaka::LocalReviewComment.render(content)

  def teardown
    Array(@reports).each { |path| FileUtils.rm_f(path) }
  end
end

class LocalReviewCommentTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_opens_with_a_title_and_a_summary_row_for_the_round
    body = render('rounds' => [round])

    assert body.start_with?("# Local Adversarial Review\n\n| Round | Commit | Reviewer | Model |")
    assert_includes body, '| 1 | `aaaaaaa` | openai/codex | gpt-5.5 | UNKNOWN | ' \
                          'Shaka default · criteria `ccccccc` | 1 | 41,200 | UNKNOWN |'
  end

  def test_collapses_each_report_and_closes_with_the_last_attestation
    body = render('rounds' => [round(EARLIER), round])

    assert_equal 2, body.scan("<details>\n<summary>Round ").size
    assert_includes body, "<summary>Round 1 · bbbbbbb · openai/codex · effort UNKNOWN · 1 finding</summary>\n\n1. [P2]"
    assert body.end_with?("</details>\n\nREVIEWED #{HEAD} BY openai/codex EFFORT UNKNOWN FINDINGS 1\n")
  end

  # Break caught: a comment whose last line is not the pushed head's attestation silently fails merge.
  def test_merge_accepts_the_published_comment_as_evidence_for_the_last_round
    marked = "<!-- shaka:reply:#{Shaka::LocalReviewComment::KEY} -->\n#{render('rounds' => [round(EARLIER), round])}"
    github = Struct.new(:issue_comments) { def viewer_login = 'agent' }
    comment = { 'user' => { 'login' => 'agent' }, 'body' => marked, 'html_url' => 'https://example.test/c/1' }

    result = Shaka::MergeReviewEvidence.new(github.new([comment]), required: 'meaningful_changes').call(HEAD)

    assert_equal %w[current_head openai/codex], result.values_at('basis', 'reviewer')
  end

  # Break caught: a supplied `\|` escaped only its pipe and split the row into an extra column.
  def test_keeps_a_supplied_backslash_and_pipe_inside_one_cell
    body = render('rounds' => [round(model: 'a\\|b')])

    assert_includes body, '| a\\\\\\|b |'
  end

  def test_names_missing_criteria_and_a_configured_prompt
    body = render('rounds' => [round(criteria_ref: nil, prompt_source: 'review.prompt_file .agents/p.md')])

    assert_includes body, '| review.prompt_file .agents/p.md · criteria not supplied |'
  end

  def test_explains_a_fallback_with_each_attempt_and_the_setup_guide
    attempts = [{ 'reviewer' => 'xai/grok', 'failure_stage' => 'executable_missing',
                  'reason' => 'grok is not on PATH' }]
    body = render('rounds' => [round], 'fallback' => { 'outcome' => 'same_provider', 'attempts' => attempts })

    assert_includes body, 'used `same_provider`. [Add a second reviewer](https://github.com/shakacode/shaka/' \
                          'blob/main/docs/settings.md#add-a-second-reviewer)'
    assert_includes body, '- `xai/grok`: `executable_missing`: grok is not on PATH'
  end

  def test_a_different_provider_review_shows_no_fallback_notice
    body = render('rounds' => [round], 'fallback' => { 'outcome' => 'different_provider' })

    refute_includes body, 'Reviewer fallback'
  end

  def test_refuses_a_report_that_does_not_attest_its_round
    error = assert_raises(Shaka::Error) { render('rounds' => [round(report: report(EARLIER))]) }

    assert_includes error.message, "does not close with REVIEWED #{HEAD}"
  end

  # Break caught: with no other provider configured, selection falls back without trying one.
  def test_explains_a_fallback_that_tried_no_other_reviewer
    body = render('rounds' => [round], 'fallback' => { 'outcome' => 'same_model', 'attempts' => [] })

    assert_includes body, 'used `same_model`.'
    refute_includes body, 'Tried:'
  end
end

# Publishes the rendered comment under one stable key.
class LocalReviewPublishTest < Minitest::Test
  include LocalReviewCommentFixture

  ATTESTATION = "REVIEWED #{HEAD} BY openai/codex EFFORT UNKNOWN FINDINGS 1".freeze
  # GitHub's markdown API output for a well-formed one-round comment, trimmed to what the check reads.
  RENDERED = "<h1>Local Adversarial Review</h1>\n<details>\n<summary>Round 1</summary>\n<p>ok</p>\n" \
             "<p>#{ATTESTATION}</p>\n</details>\n<p>#{ATTESTATION}</p>".freeze
  # What GitHub returned when a report opened a four-backtick fence and closed it with three.
  SWALLOWED = "<details>\n<summary>Round 1</summary>\n<pre><code>code\n```\n\n#{ATTESTATION}\n\n" \
              "&lt;/details&gt;\n\n#{ATTESTATION}\n</code></pre></details>".freeze

  # Records the reply instead of calling GitHub, and renders Markdown as told.
  class FakeGitHub
    attr_reader :replies

    def initialize(html = RENDERED)
      @html = html
      @replies = []
    end

    def markdown(_body) = @html

    def reply(body:, key:)
      @replies << [key, body]
      { 'id' => 1 }
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

  def test_publishes_under_the_local_review_key
    github = FakeGitHub.new

    status, = publish(github, 'rounds' => [round])

    assert_equal 0, status
    assert_equal ['local-adversarial-review'], github.replies.map(&:first)
    assert github.replies.first.last.start_with?('# Local Adversarial Review')
  end

  # Break caught: a report's unclosed fence hid the closing details and the attestation, yet merge
  # would still have read the raw last line as evidence.
  def test_refuses_when_github_would_swallow_the_attestation
    [SWALLOWED, RENDERED.sub('</details>', ''), RENDERED.sub('<details>', '<details><details>')].each do |html|
      github = FakeGitHub.new(html)

      status, _out, err = publish(github, 'rounds' => [round])

      assert_equal 1, status
      assert_empty github.replies
      assert_includes err, 'leaves its markup open'
    end
  end
end
