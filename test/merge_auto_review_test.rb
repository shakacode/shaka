# frozen_string_literal: true

require 'tmpdir'
require_relative 'merge_test'
require 'shaka/local_review/loop_comment'

# Under Auto no person looked at the review's findings, so open ones stop the merge.
class MergeAutoReviewTest < Minitest::Test
  include MergeFixtures

  def setup
    super
    @client.define_singleton_method(:api) { |_path, expected: Hash, **| expected == Array ? [] : {} }
    @client.head_checks = [{ 'name' => 'Validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
    @merge.auto = true
  end

  def test_refuses_open_findings_in_the_published_review
    @client.comments = [published_review(finding('open'), finding('decision_needed', note: 'Yours to pick.'))]

    assert_blocked(/2 findings needing attention/)
  end

  def test_a_waiver_or_review_not_required_does_not_excuse_open_findings
    @client.comments = [published_review(finding('open'))]

    [{ waiver: 'Ship it.' }, { required: 'none' }].each do |review|
      @merge = Shaka::Merge.new(@client, review:)
      @merge.auto = true

      assert_blocked(/1 finding needing attention/)
    end
  end

  def test_merges_once_a_maintainer_accepted_the_finding
    @client.comments = [published_review(finding('accepted', note: 'Known.', decision: 'Maintainer accepted it.'))]

    assert_equal 'MERGED', merge.fetch('state')
  end

  # A waiver covers comments GitHub cannot list for an Ask merge; Auto cannot tell whether findings are open.
  def test_refuses_when_the_comments_cannot_be_read_despite_a_waiver
    @client.define_singleton_method(:issue_comments) { raise Shaka::Error, 'gh api comments failed.' }
    @merge = Shaka::Merge.new(@client, review: { waiver: 'Ship it.' })
    @merge.auto = true

    assert_blocked(/comments failed/)
  end

  # Under Ask a person names the head to merge, and `attention --state merge` already refused the label.
  def test_without_auto_open_findings_do_not_refuse_the_merge
    @merge.auto = false
    @client.comments = [published_review(finding('open'))]

    assert_equal 'MERGED', merge.fetch('state')
  end

  private

  def finding(disposition, **extra)
    { 'id' => "f-#{disposition}", 'summary' => 'A concern.', 'class' => 'risk', 'disposition' => disposition,
      **extra.transform_keys(&:to_s) }
  end

  # Rendered through the real comment class, so the refusal is tested against what `review publish` writes.
  def published_review(*findings)
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.md')
      File.write(report, "REVIEWED #{HEAD} BY openai/codex EFFORT high FINDINGS #{findings.size}\n")
      round = { 'head' => HEAD, 'reviewer' => 'openai/codex', 'report' => report, 'findings' => findings }
      { 'user' => { 'login' => 'shaka-agent' }, 'html_url' => 'https://example.test/c/2',
        'body' => Shaka::LocalReviewLoopComment.new({ 'rounds' => [round] }).render }
    end
  end

  def merge = @merge.call(head: HEAD, base: BASE, walkthrough: 17)
end
