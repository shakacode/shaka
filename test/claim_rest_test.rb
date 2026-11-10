# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'claim_helpers'
require_relative 'claim_rest_helpers'

# Claim in a session where GitHub refuses GraphQL, as Claude Code cloud sessions do.
class ClaimRestTest < Minitest::Test
  include ClaimHelpers
  include ClaimRestHelpers

  def test_a_graphql_refusal_reads_open_pull_requests_over_rest_and_names_what_it_could_not_read
    result = claim_over_rest('392', pulls: [PULL, PULL.merge('number' => 403, 'body' => nil)])

    assert result.fetch('collision')
    assert_equal([402], result.fetch('pull_requests').map { |pr| pr.fetch('number') })
    assert_equal 'rest', result.fetch('readOver')
    assert_equal ['closingIssuesReferences'], result.fetch('unknownFields')
  end

  def test_rest_search_is_scoped_to_open_pull_requests_in_this_repository
    seen = []
    claim_over_rest('392', pulls: [], seen: seen)

    query = seen.find { |argv| argv.include?('search/issues') }.find { |arg| arg.start_with?('q=') }
    assert_equal 'q=repo:shakacode/shaka is:pr is:open 392', query
  end

  def test_a_search_hit_found_only_in_comments_is_reported_over_rest
    pull = PULL.merge('body' => '', 'head' => { 'ref' => 'alex/other' })
    comments = [{ 'body' => 'This covers #392.' }]
    result = claim_over_rest('392', pulls: [pull], search: [{ 'number' => 402 }], comments: comments)

    assert_equal([402], result.fetch('pull_requests').map { |pr| pr.fetch('number') })
  end

  def test_a_description_task_matches_branch_names_over_rest
    pull = PULL.merge('head' => { 'ref' => 'jg-claude/ad-hoc-add-button-counter' })
    result = Shaka::Claim.new(query: Shaka::Claim::Description.new(slug: 'add-button-counter'), root: Dir.pwd,
                              runner: rest_runner(pulls: [pull])).result

    assert_equal([%w[headRefName number title url]], result.fetch('pull_requests').map { |pr| pr.keys.sort })
    assert_equal 'rest', result.fetch('readOver')
    assert_empty result.fetch('unknownFields')
  end

  def test_an_incomplete_or_full_search_is_not_a_complete_ownership_check
    [{ 'incomplete_results' => true, 'items' => [] }, :full].each do |search|
      error = assert_raises(Shaka::Error) { claim_over_rest('392', pulls: [], search: search) }
      assert_match(/incomplete/, error.message)
    end
  end

  def test_a_pull_request_without_body_metadata_is_an_error_not_a_clear_result
    pull = PULL.except('body').merge('title' => 'Unrelated', 'head' => { 'ref' => 'alex/other' })
    error = assert_raises(Shaka::Error) { claim_over_rest('392', pulls: [pull]) }
    assert_includes error.message, 'incomplete pull request metadata'
  end

  def test_a_failed_rest_read_after_the_refusal_is_an_error_not_a_clear_result
    inner = rest_runner(pulls: [])
    broken = lambda do |argv, **|
      argv.last.to_s.include?('/pulls?') ? ['', 'HTTP 500', ClaimHelpers::STATUS.new(1)] : inner.call(argv)
    end
    assert_raises(Shaka::Error) { Shaka::Claim.new(query: '392', root: Dir.pwd, runner: broken).result }
  end

  def test_a_graphql_read_reports_no_unknown_fields
    result = claim('392', prs: [], branches: '')

    refute result.key?('readOver')
    refute result.key?('unknownFields')
  end
end
