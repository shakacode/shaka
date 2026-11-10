# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/claim'
require_relative 'claim_helpers'

# Claim in a session where GitHub refuses GraphQL, as Claude Code cloud sessions do.
class ClaimRestTest < Minitest::Test
  include ClaimHelpers

  REFUSAL = 'HTTP 403: GitHub GraphQL is not available from Claude Code sessions (https://api.github.com/graphql)'
  PULL = { 'number' => 402, 'title' => 'Feedback', 'html_url' => 'https://github.com/shakacode/shaka/pull/402',
           'head' => { 'ref' => 'alex/fix' }, 'body' => 'Part of #392' }.freeze

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

  def test_an_owning_pull_request_on_a_later_page_is_found
    others = Array.new(100) { |index| PULL.merge('number' => 1000 + index, 'body' => '') }
    result = Shaka::Claim.new(query: '392', root: Dir.pwd, runner: rest_runner(pulls: [others, [PULL]])).result

    assert_equal([402], result.fetch('pull_requests').map { |pr| pr.fetch('number') })
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

  private

  def claim_over_rest(query, pulls:, search: [], comments: [], seen: [])
    Shaka::Claim.new(query: query, root: Dir.pwd,
                     runner: rest_runner(pulls:, search:, comments:, seen:)).result
  end

  def rest_runner(pulls:, search: [], comments: [], seen: [])
    lambda do |argv, **|
      seen << argv
      reply = rest_reply(argv, pulls, search, comments)
      reply ? [JSON.generate(reply), '', ClaimHelpers::STATUS.new(0)] : other_reply(argv)
    end
  end

  def rest_reply(argv, pulls, search, comments)
    return unless argv[1] == 'api'
    return { 'full_name' => 'shakacode/shaka' } if argv.last == 'repos/{owner}/{repo}'
    return search_result(search) if argv.include?('search/issues')
    return pulls_page(pulls, argv.last) if argv.last.start_with?('repos/shakacode/shaka/pulls?')

    comments
  end

  # Pages given as an array of arrays; a flat array is the first page alone.
  def pulls_page(pulls, path)
    pages = pulls.first.is_a?(Array) ? pulls : [pulls]
    pages.fetch(path[/[?&]page=(\d+)/, 1].to_i - 1, [])
  end

  def search_result(search)
    return search if search.is_a?(Hash)

    items = search == :full ? Array.new(100) { |index| { 'number' => index + 1 } } : search
    { 'incomplete_results' => false, 'items' => items }
  end

  def other_reply(argv)
    return ['', REFUSAL, ClaimHelpers::STATUS.new(1)] if argv[1] == 'pr'
    return ['', '', ClaimHelpers::STATUS.new(0)] if argv[1] == 'ls-remote'

    raise "Unexpected command: #{argv.inspect}"
  end
end
