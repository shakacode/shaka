# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'shaka/merge_wait_review'
require 'shaka/local_review/ledger'
require 'shaka/local_review/loop_comment'

# Renders the review comment the helper publishes, so the gate is tested against what it reads.
module MergeWaitReviewFixtures
  HEAD = 'a' * 40
  EARLIER = 'c' * 40
  BASE = 'b' * 40
  ACCOUNT = 'shaka-agent'

  class Client
    attr_accessor :comments, :comparisons

    def initialize
      @comments = []
      @comparisons = {}
    end

    def viewer_login = ACCOUNT
    def issue_comments = comments
    def compare(from, _to) = comparisons.fetch(from) { raise Shaka::Error, 'gh api compare failed.' }
  end

  def setup
    @client = Client.new
  end

  def snapshot(head = HEAD) = { 'state' => 'OPEN', 'headRefOid' => head, 'baseRefName' => 'main' }

  def gate(**) = Shaka::MergeWaitReview.new(@client, **)

  def finding(disposition, kind: 'risk', **extra)
    { 'id' => "f-#{disposition}", 'summary' => 'A concern.', 'class' => kind, 'disposition' => disposition,
      **extra.transform_keys(&:to_s) }
  end

  # A published review of head whose findings stand as given, rendered through the real comment class.
  def published(findings, head: HEAD, extra_report: '')
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.md')
      File.write(report, "#{extra_report}\nREVIEWED #{head} BY openai/codex EFFORT high FINDINGS #{findings.size}\n")
      round = { 'head' => head, 'reviewer' => 'openai/codex', 'report' => report, 'findings' => findings }
      body = Shaka::LocalReviewLoopComment.new({ 'rounds' => [round] }).render
      { 'user' => { 'login' => ACCOUNT }, 'html_url' => 'https://example.test/c/1', 'body' => body }
    end
  end
end

class MergeWaitReviewTest < Minitest::Test
  include MergeWaitReviewFixtures

  # `review publish` refuses a report whose findings are unrecorded, so nothing is on the PR yet.
  def test_a_review_that_could_not_publish_refuses_the_label
    error = assert_raises(Shaka::MergeReviewEvidence::Missing) { gate.check!(snapshot) }

    assert_includes error.message, HEAD
    assert_includes error.message, '--review-waiver'
  end

  def test_a_commit_after_the_published_review_refuses_the_label
    @client.comments = [published([], head: EARLIER)]
    @client.comparisons[EARLIER] = { 'status' => 'ahead', 'files' => [{ 'filename' => 'lib/fix.rb' }] }

    assert_raises(Shaka::MergeReviewEvidence::Missing) { gate.check!(snapshot) }
  end

  def test_open_findings_refuse_the_label_and_are_counted
    @client.comments = [published([finding('open'), finding('decision_needed', note: 'Yours to pick.')])]

    error = assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }

    assert_includes error.message, '2 findings'
    assert_includes error.message, 'review record'
  end

  def test_a_documented_risk_still_counts_as_open_and_a_documented_nit_does_not
    @client.comments = [published([finding('documented')])]
    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }

    @client.comments = [published([finding('documented', kind: 'nit')])]
    assert_equal 'current_head', gate.check!(snapshot)['basis']
  end

  def test_settled_findings_allow_the_label
    @client.comments = [published([finding('dismissed', note: 'Disproved by the test.'),
                                   finding('accepted', note: 'Known.', decision: 'Maintainer accepted it.')])]

    assert_equal 'current_head', gate.check!(snapshot)['basis']
  end

  def test_a_clean_review_allows_the_label
    @client.comments = [published([])]

    assert_equal 'current_head', gate.check!(snapshot)['basis']
  end

  def test_a_stated_reason_allows_the_label_when_no_review_ran
    result = gate(waiver: 'Docs typo; no code changed.').check!(snapshot)

    assert_equal({ 'basis' => 'waived', 'reason' => 'Docs typo; no code changed.' }, result)
  end

  def test_a_stated_reason_does_not_excuse_a_published_open_finding
    @client.comments = [published([finding('open')])]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate(waiver: 'Ship it.').check!(snapshot) }
  end

  def test_a_repository_that_requires_no_review_allows_the_label_without_one
    assert_equal({ 'basis' => 'not_required' }, gate(required: 'none').check!(snapshot))
  end

  def test_a_review_run_anyway_still_holds_its_open_findings_when_none_is_required
    @client.comments = [published([finding('open')])]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate(required: 'none').check!(snapshot) }
  end

  def test_a_report_cannot_clear_the_count_by_imitating_the_outcome_line
    imitation = '**Outcome:** No open findings; closed and optional findings are in history.'
    @client.comments = [published([finding('open')], extra_report: imitation)]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }
  end

  def test_a_report_cannot_block_a_clean_review_by_imitating_the_outcome_line
    @client.comments = [published([], extra_report: '**Outcome:** 5 findings need attention.')]

    assert_equal 'current_head', gate.check!(snapshot)['basis']
  end

  def test_another_accounts_comment_is_not_evidence
    @client.comments = [published([]).merge('user' => { 'login' => 'someone-else' })]

    assert_raises(Shaka::MergeReviewEvidence::Missing) { gate.check!(snapshot) }
  end

  def test_a_comment_without_an_outcome_line_is_read_as_a_review
    body = "# Local Adversarial Review\n\nREVIEWED #{HEAD} BY openai/codex EFFORT high FINDINGS 2"
    @client.comments = [{ 'user' => { 'login' => ACCOUNT }, 'html_url' => 'https://example.test/c/1', 'body' => body }]

    assert_equal 'current_head', gate.check!(snapshot)['basis']
  end

  def test_a_review_of_an_earlier_commit_keeps_its_open_findings_across_a_markdown_only_change
    @client.comments = [published([finding('open')], head: EARLIER)]
    @client.comparisons[EARLIER] = { 'status' => 'ahead', 'files' => [{ 'filename' => 'docs/guide.md' }] }

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }
  end

  def test_a_stated_reason_does_not_excuse_open_findings_published_for_an_earlier_commit
    @client.comments = [published([finding('open')], head: EARLIER)]
    @client.comparisons[EARLIER] = { 'status' => 'ahead', 'files' => [{ 'filename' => 'lib/fix.rb' }] }

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate(waiver: 'Skip review.').check!(snapshot) }
  end

  def test_a_closed_pr_is_left_to_the_label_command
    assert_nil gate.check!(snapshot.merge('state' => 'MERGED'))
  end
end

# Which published comment speaks for the review, and what can't change its answer.
class MergeWaitReviewPublishedCommentTest < Minitest::Test
  include MergeWaitReviewFixtures

  def test_a_continuation_comment_does_not_hide_the_main_comments_open_findings
    continuation = "# Local Adversarial Review · earlier commits (1)\n\n**Outcome:** No open findings.\n\n" \
                   "REVIEWED #{EARLIER} BY openai/codex EFFORT high FINDINGS 0\n"
    main = published([finding('open')])
    @client.comments = [main, main.merge('body' => continuation)]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }
  end

  def test_a_newer_clean_ledger_speaks_for_the_review
    @client.comments = [published([finding('open')], head: EARLIER).merge('updated_at' => '2026-10-30T01:00:00Z'),
                        published([]).merge('updated_at' => '2026-10-30T02:00:00Z')]

    assert_equal 'current_head', gate.check!(snapshot)['basis']
  end

  # Republishing an older ledger edits its comment in place, so it stays first in GitHub's listing.
  def test_an_older_ledger_republished_with_open_findings_speaks_for_the_review
    @client.comments = [published([finding('open')]).merge('updated_at' => '2026-10-30T03:00:00Z'),
                        published([], head: EARLIER).merge('updated_at' => '2026-10-30T02:00:00Z')]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }
  end

  def test_a_tie_between_published_reviews_reads_as_open
    same = { 'updated_at' => '2026-10-30T03:00:00Z' }
    @client.comments = [published([finding('open')]).merge(same), published([], head: EARLIER).merge(same)]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }
  end

  def test_a_comment_saved_with_crlf_line_endings_keeps_its_open_findings
    comment = published([finding('open')])
    comment['body'] = comment['body'].gsub("\n", "\r\n")
    @client.comments = [comment]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }
  end

  def test_the_comment_github_stores_is_read_with_its_reply_key
    comment = published([finding('open')])
    comment['body'] = "<!-- shaka:reply:local-review-loop-abc-def -->\n#{comment['body']}"
    @client.comments = [comment]

    assert_raises(Shaka::MergeWaitReview::OpenFindings) { gate.check!(snapshot) }
  end
end
