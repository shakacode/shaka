# frozen_string_literal: true

require_relative 'github_helper'

# Publication refuses a wall of text before anything is written to GitHub.
class GitHubProseLimitsTest < Minitest::Test
  include GitHubHelper

  WALL = Array.new(9) { "Alpha #{Array.new(18, 'word').join(' ')} end." }.join("\n\n")

  def test_description_is_refused_before_the_pull_request_is_edited
    github = client(response({ 'id' => 1, 'body' => '', 'additions' => 4, 'deletions' => 2 }))

    error = assert_raises(Shaka::Error) { github.description(body: WALL) }

    assert_includes error.message, 'Description is hard to read'
    assert_equal 1, @calls.size
  end

  def test_walkthrough_is_refused_before_the_review_is_posted
    pull = { 'headRefOid' => HEAD, 'state' => 'OPEN', 'additions' => 4, 'deletions' => 2 }
    github = client(response({ 'data' => { 'repository' => { 'pullRequest' => pull } } }))

    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALL) }

    assert_includes error.message, 'Walkthrough is hard to read'
    assert_equal 1, @calls.size
  end
end
