# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/merge_review_evidence'

class MergeReviewEvidenceTest < Minitest::Test
  HEAD = 'a' * 40
  EARLIER = 'c' * 40
  ACCOUNT = 'shaka-agent'

  # Serves the three GitHub reads evidence needs.
  class Client
    attr_accessor :comments, :comparisons
    attr_reader :compared

    def initialize
      @comments = []
      @comparisons = {}
      @compared = []
    end

    def viewer_login = ACCOUNT

    def issue_comments = comments

    def compare(from, to)
      @compared << [from, to]
      result = comparisons.fetch(from) { raise Shaka::Error, 'gh api compare failed (exit 1).' }
      raise result if result.is_a?(Exception)

      result
    end
  end

  def setup
    @client = Client.new
  end

  def attestation(sha, reviewer: 'openai/codex', author: ACCOUNT, url: 'https://example.test/c/1')
    { 'user' => { 'login' => author }, 'html_url' => url,
      'body' => "<!-- shaka:reply:review -->\nNo findings.\n\nREVIEWED #{sha} BY #{reviewer} EFFORT high FINDINGS 0\n" }
  end

  def evidence(required: 'meaningful_changes', waiver: nil)
    Shaka::MergeReviewEvidence.new(@client, required:, waiver:).call(HEAD)
  end

  def markdown_only(*names)
    { 'status' => 'ahead', 'files' => names.map { |name| { 'filename' => name, 'status' => 'modified' } } }
  end

  def test_accepts_an_attestation_for_the_exact_head
    @client.comments = [attestation(HEAD)]

    result = evidence

    assert_equal 'current_head', result.fetch('basis')
    assert_equal HEAD, result.fetch('reviewed')
    assert_equal 'openai/codex', result.fetch('reviewer')
    assert_equal 'https://example.test/c/1', result.fetch('comment')
    assert_empty @client.compared
  end

  def test_accepts_a_same_model_review
    @client.comments = [attestation(HEAD, reviewer: 'anthropic/claude')]

    assert_equal 'anthropic/claude', evidence.fetch('reviewer')
  end

  def test_refuses_when_no_attestation_exists
    error = assert_raises(Shaka::Error) { evidence }

    assert_match(/No local-review attestation/, error.message)
    assert_match(/--review-waiver/, error.message)
  end

  def test_ignores_attestations_other_accounts_wrote
    @client.comments = [attestation(HEAD, author: 'someone-else')]

    assert_raises(Shaka::Error) { evidence }
  end

  def test_ignores_an_attestation_that_is_not_its_own_line
    @client.comments = [{ 'user' => { 'login' => ACCOUNT },
                          'body' => "Quoted: `REVIEWED #{HEAD} BY openai/codex EFFORT high FINDINGS 0`" }]

    assert_raises(Shaka::Error) { evidence }
  end

  def test_accepts_an_earlier_attestation_when_only_markdown_changed_since
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => markdown_only('README.md', 'docs/Guide.MD') }

    result = evidence

    assert_equal 'markdown_only_since_review', result.fetch('basis')
    assert_equal EARLIER, result.fetch('reviewed')
    assert_equal %w[README.md docs/Guide.MD], result.fetch('changed_since_review')
    assert_equal [[EARLIER, HEAD]], @client.compared
  end

  def test_refuses_an_earlier_attestation_when_code_changed_since
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => markdown_only('README.md', 'lib/merge.rb') }

    error = assert_raises(Shaka::Error) { evidence }

    assert_includes error.message, EARLIER
    assert_match(/non-Markdown/, error.message)
  end

  def test_refuses_a_rename_from_a_non_markdown_path
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => { 'status' => 'ahead', 'files' => [
      { 'filename' => 'notes.md', 'previous_filename' => 'run.rb', 'status' => 'renamed' }
    ] } }

    assert_raises(Shaka::Error) { evidence }
  end

  # After a rebase the reviewed commit is no longer an ancestor, so its diff says nothing about the head.
  def test_refuses_an_attestation_that_is_not_an_ancestor
    @client.comments = [attestation(EARLIER)]
    @client.comparisons = { EARLIER => markdown_only('README.md').merge('status' => 'diverged') }

    assert_raises(Shaka::Error) { evidence }
  end

  def test_refuses_a_comparison_that_may_be_truncated
    @client.comments = [attestation(EARLIER)]
    names = Array.new(Shaka::MergeReviewEvidence::COMPARE_FILE_LIMIT) { |index| "docs/#{index}.md" }
    @client.comparisons = { EARLIER => markdown_only(*names) }

    assert_raises(Shaka::Error) { evidence }
  end

  def test_an_unreadable_comparison_does_not_hide_a_usable_older_attestation
    older = 'd' * 40
    @client.comments = [attestation(older), attestation(EARLIER)]
    @client.comparisons = { older => markdown_only('README.md') }

    assert_equal older, evidence.fetch('reviewed')
  end

  def test_waiver_is_reported_when_no_evidence_exists
    result = evidence(waiver: '  Prose-only change; claude-review covered it  ')

    assert_equal 'waived', result.fetch('basis')
    assert_equal 'Prose-only change; claude-review covered it', result.fetch('reason')
  end

  def test_evidence_is_preferred_over_a_waiver
    @client.comments = [attestation(HEAD)]

    assert_equal 'current_head', evidence(waiver: 'not needed').fetch('basis')
  end

  def test_blank_waiver_is_refused
    error = assert_raises(Shaka::Error) { evidence(waiver: '  ') }

    assert_match(/--review-waiver needs a reason/, error.message)
  end

  def test_review_required_none_needs_no_evidence
    assert_equal 'not_required', evidence(required: 'none').fetch('basis')
  end
end
