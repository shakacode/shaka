# frozen_string_literal: true

require 'json'
require 'shaka/claim'
require_relative 'claim_helpers'

# Runs `Shaka::Claim` where `gh pr list` meets GitHub's GraphQL refusal and REST answers.
module ClaimRestHelpers
  REFUSAL = 'HTTP 403: GitHub GraphQL is not available from Claude Code sessions (https://api.github.com/graphql)'
  PULL = { 'number' => 402, 'title' => 'Feedback', 'html_url' => 'https://github.com/shakacode/shaka/pull/402',
           'head' => { 'ref' => 'alex/fix' }, 'body' => 'Part of #392' }.freeze

  private

  # A full first page of pull requests that do not mention the query.
  def unrelated_page = Array.new(100) { |index| PULL.merge('number' => 1000 + index, 'body' => '') }

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
