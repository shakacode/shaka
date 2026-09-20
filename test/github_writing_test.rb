# frozen_string_literal: true

require_relative 'github_helper'

# Neither renderer holds both bodies, so each surface fetches its published sibling.
class GitHubWritingTest < Minitest::Test
  include GitHubHelper

  COPIED = 'The loader now rejects an unknown review mode before the workflow starts.'
  IDENTITY = '🤖 Claude · Anthropic · claude-opus-5 · medium'
  SUMMARY = "#{IDENTITY}\n\n#{COPIED} Maintainers merge without the diff.\n".freeze
  LINK = "## Code Walkthrough\n\n[Code Walkthrough](https://github.com/owner/repo/pull/42#pullrequestreview-9)"

  def pull_body(body) = response({ 'id' => 1, 'number' => 42, 'body' => body })

  def managed(body) = pull_body("<!-- shaka:begin -->\n#{body}<!-- shaka:end -->")

  def walkthrough_body = "#{IDENTITY}\n\n# Code Walkthrough\n\n#{COPIED}\n\n#{WALKTHROUGH}"

  def reviews(*bodies, login: 'shaka-bot')
    response(bodies.map do |body|
      { 'id' => 9, 'state' => 'COMMENTED', 'body' => body, 'user' => { 'login' => login } }
    end)
  end

  def viewer_response = response({ 'login' => 'shaka-bot' })

  def test_description_repeating_the_published_walkthrough_is_refused_before_any_write
    github = client(pull_body('old'), reviews(walkthrough_body), viewer_response)
    error = assert_raises(Shaka::Error) { github.description(body: "#{SUMMARY}\n#{LINK}\n") }
    assert_includes error.message, 'This description repeats'
    assert_equal 3, @calls.size
  end

  # The sibling comes from GitHub, so dropping the link cannot excuse the comparison.
  def test_a_description_that_omits_its_walkthrough_link_is_still_compared
    github = client(pull_body('old'), reviews(walkthrough_body), viewer_response)
    error = assert_raises(Shaka::Error) { github.description(body: SUMMARY) }
    assert_includes error.message, 'This description repeats'
  end

  # Publishing the first description has no walkthrough beside it yet.
  def test_a_description_published_before_any_walkthrough_is_not_compared
    body = "#{SUMMARY}\n## Code Walkthrough\n\n_Not published yet._\n"
    merged = "<!-- shaka:begin -->\n#{body}<!-- shaka:end -->"
    github = client(pull_body(''), reviews, html_response('<p>ok</p>'), pull_body(''), pull_body(merged))
    assert_equal merged, github.description(body: body)['body']
  end

  # An ordinary approval or a human comment is not the walkthrough.
  def test_an_untitled_review_is_not_treated_as_the_walkthrough
    plain = response([{ 'id' => 9, 'state' => 'APPROVED', 'body' => walkthrough_body,
                        'user' => { 'login' => 'shaka-bot' } },
                      { 'id' => 8, 'state' => 'COMMENTED', 'body' => COPIED,
                        'user' => { 'login' => 'shaka-bot' } }])
    publishes_description(plain)
  end

  # Anyone may review a public pull request, so a titled review is not authority.
  def test_a_titled_review_by_another_author_is_not_treated_as_the_walkthrough
    publishes_description(reviews(walkthrough_body, login: 'outsider'), viewer_response)
  end

  # A later review quoting the title is not the walkthrough it quotes.
  def test_a_review_that_only_quotes_the_walkthrough_title_is_not_the_sibling
    publishes_description(reviews("#{IDENTITY}\n\nOn '# Code Walkthrough':\n\n#{COPIED}"))
  end

  def publishes_description(*siblings)
    body = "#{SUMMARY}\n#{LINK}\n"
    merged = "<!-- shaka:begin -->\n#{body}<!-- shaka:end -->"
    github = client(pull_body(''), *siblings, html_response('<p>ok</p>'), pull_body(''), pull_body(merged))
    assert_equal merged, github.description(body: body)['body']
  end

  # A review listing that cannot be read leaves the gate unproven, so it fails closed.
  def test_an_unreadable_review_listing_stops_the_description
    github = client(pull_body(''), response({ 'message' => 'gone' }, status: 1))
    assert_raises(Shaka::Error) { github.description(body: "#{SUMMARY}\n#{LINK}\n") }
  end

  def test_walkthrough_repeating_the_published_description_is_refused_before_its_evidence
    github = client(snapshot_response, managed(SUMMARY))
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: walkthrough_body) }
    assert_includes error.message, 'This walkthrough repeats'
    assert_equal 2, @calls.size
  end

  def test_a_walkthrough_published_before_any_description_is_not_compared
    assert_equal 123, publishes(pull_body(''))
  end

  # Another bot's summary in the same body is not this writer's prose to answer for.
  def test_only_the_managed_region_of_the_description_is_compared
    assert_equal 123, publishes(pull_body("#{SUMMARY}\n<!-- shaka:begin -->\nOther.\n<!-- shaka:end -->"))
  end

  def publishes(description)
    github = client(snapshot_response, description, files_response, *gate_responses, html_response,
                    review_response(body: walkthrough_body), review_response(body: walkthrough_body),
                    snapshot_response)
    github.walkthrough(head: HEAD, body: walkthrough_body)['id']
  end
end
