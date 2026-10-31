# frozen_string_literal: true

require_relative 'handoff_helper'
require 'shaka/local_review/loop_comment'
require 'tmpdir'

class HandoffReviewTest < Minitest::Test
  include HandoffHarness

  LABELED = { labels: ['awaiting-merge-approval'] }.freeze

  def review(findings)
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.md')
      File.write(report, "REVIEWED #{HEAD} BY openai/codex EFFORT high FINDINGS #{findings.size}\n")
      round = { 'head' => HEAD, 'reviewer' => 'openai/codex', 'report' => report, 'findings' => findings }
      comment(9, Shaka::LocalReviewLoopComment.new({ 'rounds' => [round] }).render)
    end
  end

  def open_finding = { 'id' => 'f1', 'summary' => 'A defect.', 'class' => 'defect', 'disposition' => 'open' }

  def reviewed_handoff(required: 'meaningful_changes', **pull)
    defaults = { state: 'OPEN', head: HEAD, labels: ['awaiting-resume'], body: description,
                 reviews: [walkthrough(HEAD)], checks: [check('pass')], comments: [] }
    Shaka::Handoff.new(HandoffFakeGitHub.new(defaults.merge(pull)), review: { required: }).call(head: HEAD)
  end

  def test_a_merge_wait_with_open_findings_is_owed
    result = reviewed_handoff(**LABELED, comments: [review([open_finding])])

    assert(result['owed'].any? { |item| item.include?('1 finding') })
    assert_includes result['status'], 'local review owed'
  end

  def test_a_merge_wait_with_no_published_review_says_so_without_owing_it
    result = reviewed_handoff(**LABELED)

    assert(result['notes'].any? { |item| item.include?("No published local review covers #{HEAD}") })
    assert_includes result['status'], 'no local review'
    refute(result['owed'].any? { |item| item.include?('local review') })
  end

  def test_a_clean_review_adds_nothing_to_a_merge_wait
    result = reviewed_handoff(**LABELED, comments: [review([])])

    assert_empty result['notes']
    refute_includes result['status'], 'local review'
  end

  def test_a_repository_that_requires_no_review_hears_nothing_about_one
    result = reviewed_handoff(**LABELED, required: 'none')

    assert_empty result['notes']
    refute_includes result['status'], 'local review'
  end

  # The agent is still working, so open findings are expected and nothing says otherwise.
  def test_a_pr_not_waiting_on_merge_is_not_checked
    result = reviewed_handoff(comments: [review([open_finding])])

    refute(result['owed'].any? { |item| item.include?('finding') })
    refute_includes result['status'], 'local review'
  end
end
