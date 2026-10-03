# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'claim_helpers'

class ClaimCommentTest < Minitest::Test
  include ClaimHelpers

  PR = { 'number' => 402, 'title' => 'Feedback', 'url' => 'https://github.com/shakacode/shaka/pull/402',
         'headRefName' => 'alex/400-fix', 'body' => '2,392 tests', 'closingIssuesReferences' => [] }.freeze

  def test_comment_only_references_are_collisions_without_exposing_comment_prose
    result = claim_comments { |_path| [{ 'body' => 'This PR implements #392' }] }
    assert result.fetch('collision')
    assert_equal PR.slice('number', 'title', 'url', 'headRefName'), result.fetch('pull_requests').first
  end

  def test_incidental_comment_digits_are_not_collisions
    result = claim_comments { |_path| [{ 'body' => '2,392 tests; run-392-abc; GH-3920' }] }
    refute result.fetch('collision')
  end

  def test_comment_tracker_keys_still_match
    result = claim_comments('ENG-123') { |_path| [{ 'body' => 'See eng-123' }] }
    assert result.fetch('collision')
  end

  def test_inline_comments_and_review_summaries_are_reference_evidence
    %w[pulls/402/comments pulls/402/reviews].each do |endpoint|
      result = claim_comments do |path|
        path.include?(endpoint) ? [{ 'body' => 'Related to GH-392' }] : []
      end
      assert result.fetch('collision'), endpoint
    end
  end

  def test_a_reference_on_a_later_comment_page_is_retained
    result = claim_comments do |path|
      path.end_with?('page=1') ? Array.new(100) { { 'body' => 'unrelated' } } : [{ 'body' => '#392' }]
    end
    assert result.fetch('collision')
  end

  def test_comment_pagination_limit_is_a_blocking_error
    assert_raises(Shaka::PublicComments::BoundedList::LimitError) do
      claim_comments { |_path| Array.new(100) { { 'body' => 'unrelated' } } }
    end
  end

  def test_malformed_comment_data_is_a_blocking_error
    ['not json', '{}', '[{}]', '[null]'].each do |response|
      assert_raises(Shaka::Error) { claim_comments { |_path| response } }
    end
  end

  def test_failed_comment_queries_are_a_blocking_error
    inner = runner(prs: [PR], branches: '')
    broken = lambda do |argv, **|
      argv[1] == 'api' ? ['', 'failure', ClaimHelpers::STATUS.new(1)] : inner.call(argv)
    end
    error = assert_raises(Shaka::Error) { Shaka::Claim.new(query: '392', root: Dir.pwd, runner: broken).result }
    assert_includes error.message, 'gh api failed'
  end

  private

  def claim_comments(query = '392')
    inner = runner(prs: [PR], branches: '')
    wrapped = lambda do |argv, **|
      next inner.call(argv) unless argv[1] == 'api'

      response = yield argv.last
      response = JSON.generate(response) unless response.is_a?(String)
      [response, '', ClaimHelpers::STATUS.new(0)]
    end
    Shaka::Claim.new(query: query, root: Dir.pwd, runner: wrapped).result
  end
end
