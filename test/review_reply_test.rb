# frozen_string_literal: true

require_relative 'test_helper'
require 'tempfile'
require 'shaka/local_review'
require 'shaka/publication'
require 'shaka/review_reply'

# A review reply's opening line comes from the published comment, not from text the author types.
class ReviewReplyTest < Minitest::Test
  HEAD = 'a' * 40
  OTHER = 'b' * 40
  URL = 'https://github.com/shakacode/shaka/pull/284#issuecomment-5860923804'
  HOSTED = 'https://github.com/shakacode/shaka/pull/284#issuecomment-5860935743'
  IDENTITY = { 'agent' => 'Codex', 'provider' => 'OpenAI', 'model' => 'gpt-5.5', 'effort' => 'medium' }.freeze

  def teardown
    Array(@reports).each { |path| FileUtils.rm_f(path) }
  end

  def test_names_the_reviewer_model_and_effort_from_the_published_comment
    body = compose({ 'reviews' => [URL] }, comments: [comment(URL, review_comment)])

    opening = "Addressed the [Local Adversarial Review](#{URL}) by anthropic/claude-opus-5-5 (high) on `aaaaaaa`."
    assert body.start_with?(opening)
    assert_includes body, '🤖 Codex · OpenAI · gpt-5.5 · medium'
    refute_includes body, 'anthropic/claude (high)'
  end

  # Break caught: a missing model is dropped, so a reader cannot tell it was unknown.
  def test_an_unknown_reviewer_model_is_written_as_unknown
    published = review_comment(model: nil)
    body = compose({ 'reviews' => [URL] }, comments: [comment(URL, published)])

    assert_includes body, 'by anthropic/UNKNOWN (high) on `aaaaaaa`.'
  end

  def test_names_each_review_when_several_are_addressed
    hosted = "# Claude review\n\nNo attestation here.\n"
    body = compose({ 'reviews' => [URL, HOSTED] },
                   comments: [comment(URL, review_comment), comment(HOSTED, hosted)])

    lines = body.lines.map(&:rstrip)
    assert_equal "Addressed the [Local Adversarial Review](#{URL}) by anthropic/claude-opus-5-5 (high) on `aaaaaaa`.",
                 lines[0]
    assert_equal "Addressed the [Claude review](#{HOSTED}) by UNKNOWN/UNKNOWN (UNKNOWN) on `UNKNOWN`.", lines[1]
  end

  def test_uses_the_last_round_when_the_comment_records_several
    published = review_comment(rounds: [
                                 { head: OTHER, model: 'claude-opus-4', effort: 'low' },
                                 { head: HEAD, model: 'claude-opus-5-5', effort: 'high' }
                               ])
    body = compose({ 'reviews' => [URL] }, comments: [comment(URL, published)])

    assert_includes body, 'by anthropic/claude-opus-5-5 (high) on `aaaaaaa`.'
    refute_includes body, 'claude-opus-4'
  end

  def test_a_reply_that_addresses_no_review_keeps_its_opening_line
    content = { 'identity' => IDENTITY, 'summary' => 'Fixed the race.' }
    github = FakeReviews.new([])

    assert_equal Shaka::Publication.comment(content), Shaka::ReviewReply.compose(content, github)
    assert_empty github.lookups
  end

  def test_refuses_a_reviewer_identity_typed_into_the_reply
    error = assert_raises(Shaka::Error) do
      compose({ 'reviews' => [{ 'url' => URL, 'model' => 'claude-opus-5-5' }] })
    end

    assert_includes error.message, 'comment URL'
  end

  def test_refuses_a_comment_that_is_not_on_this_pull_request
    error = assert_raises(Shaka::Error) { compose({ 'reviews' => [URL] }, comments: []) }

    assert_includes error.message, 'not found'
  end

  def test_refuses_a_comment_url_for_another_repository
    other = 'https://github.com/other/repo/pull/284#issuecomment-1'
    error = assert_raises(Shaka::Error) { compose({ 'reviews' => [other] }) }

    assert_includes error.message, 'this pull request'
  end

  private

  def compose(extra, comments: [])
    Shaka::ReviewReply.compose({ 'identity' => IDENTITY, 'summary' => 'Fixed the race.' }.merge(extra),
                               FakeReviews.new(comments))
  end

  def comment(url, body)
    { 'id' => url[/\d+\z/], 'html_url' => url, 'body' => body }
  end

  def review_comment(model: 'claude-opus-5-5', effort: 'high', rounds: nil)
    rounds ||= [{ head: HEAD, model: model, effort: effort }]
    specs = rounds.map { |round| round_spec(**round) }
    Shaka::LocalReviewComment.new({ 'rounds' => specs }, repository: 'shakacode/shaka').render
  end

  def round_spec(head:, model:, effort:, reviewer: 'anthropic/claude')
    { 'head' => head, 'reviewer' => reviewer, 'report' => report(head, reviewer, effort), 'model' => model }
  end

  def report(head, reviewer, effort)
    file = Tempfile.create(['report-', '.md'])
    file.write("ok\nREVIEWED #{head} BY #{reviewer} EFFORT #{effort} FINDINGS 0\n")
    file.close
    (@reports ||= []) << file.path
    file.path
  end

  # Records which comment lists a reply asked for, so an ordinary reply does no lookup.
  class FakeReviews
    attr_reader :lookups

    def initialize(comments)
      @comments = comments
      @lookups = []
    end

    def repository = 'shakacode/shaka'
    def number = 284

    def issue_comments
      @lookups << :issues
      @comments
    end

    def api_list(*)
      @lookups << :api
      []
    end

    def review(*)
      @lookups << :review
      {}
    end
  end
end
