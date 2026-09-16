# frozen_string_literal: true

require_relative 'github_helper'

class GitHubWalkthroughTest < Minitest::Test
  include GitHubHelper

  def html_response(html = '<p>A walkthrough.</p>')
    [html, 'private stderr must not be disclosed', STATUS.new(0)]
  end

  def test_walkthrough_creates_comment_and_reads_back_the_review_and_head
    github = client(snapshot_response, html_response, review_response, review_response, snapshot_response)
    published = github.walkthrough(head: HEAD, body: 'A walkthrough.')
    assert_equal 'COMMENTED', published['state']
    assert_equal({ 'event' => 'COMMENT', 'commit_id' => HEAD, 'body' => 'A walkthrough.' },
                 JSON.parse(@calls[2].last))
    assert_equal %w[gh api repos/owner/repo/pulls/42/reviews/123 --method GET --input -], @calls[3].first
  end

  def test_changed_or_closed_head_prevents_publication
    [snapshot_response(head: 'b' * 40), snapshot_response(state: 'CLOSED')].each do |snapshot|
      assert_raises(Shaka::Error) { client(snapshot).walkthrough(head: HEAD, body: 'A walkthrough.') }
      assert_equal 1, @calls.size
    end
  end

  def test_head_change_during_publication_is_reported
    github = client(snapshot_response, html_response, review_response, review_response,
                    snapshot_response(head: 'b' * 40))
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: 'A walkthrough.') }
    assert_includes error.message, '123'
    assert_equal 5, @calls.size
  end

  def test_review_readback_requires_matching_native_state_commit_body_and_id
    mismatches = [{ 'state' => 'APPROVED' }, { 'commit_id' => 'b' * 40 }, { 'body' => 'Wrong text.' }, { 'id' => 124 }]
    mismatches.each do |changes|
      github = client(snapshot_response, html_response, review_response, review_response(**changes))
      assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: 'A walkthrough.') }
      assert_equal 4, @calls.size
    end
  end

  def test_invalid_review_publication_result_is_a_domain_error
    github = client(snapshot_response, html_response, response({}))
    assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: 'A walkthrough.') }
  end

  def test_invalid_body_or_head_never_contacts_github
    ['', '  ', "\xff".b, nil].each do |body|
      assert_raises(Shaka::Error) { client.walkthrough(head: HEAD, body: body) }
      assert_empty @calls
    end
    assert_raises(Shaka::Error) { client.walkthrough(head: 'short', body: 'A walkthrough.') }
    assert_empty @calls
  end

  def test_unauthorized_publication_does_not_attempt_readback
    github = client(snapshot_response, html_response, response({}, status: 1))
    assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: 'A walkthrough.') }
    assert_equal 3, @calls.size
  end
end
