# frozen_string_literal: true

require 'open3'
require_relative 'github_helper'

class ReviewThreadTest < Minitest::Test
  include GitHubHelper

  THREAD = 'PRRT_kwDOExample'
  SCRIPT = SHAKA_COMMAND
  AGENT_REPLY = "<!-- shaka:reply:fix -->\nFixed in abc1234."
  IDENTITY_REPLY = "\u{1F916} Claude Code \u00B7 Anthropic \u00B7 claude-opus-5-5 \u00B7 medium\n\nFixed."

  def test_resolve_marks_an_unresolved_thread_after_this_account_replied
    github = client(user_response, thread_page, mutation_response(true))

    assert_equal({ 'thread_id' => THREAD, 'is_resolved' => true }, github.resolve_thread(THREAD))
    assert_equal %w[user graphql graphql], paths
    assert_includes sent(2)['query'], 'resolveReviewThread'
    assert_equal THREAD, sent(2).dig('variables', 'id')
  end

  def test_resolve_accepts_a_reply_that_opens_with_the_identity_line
    github = client(user_response, thread_page(comments: [%w[reviewer Fix], ['justin808', IDENTITY_REPLY]]),
                    mutation_response(true))

    assert_equal({ 'thread_id' => THREAD, 'is_resolved' => true }, github.resolve_thread(THREAD))
    assert_includes sent(1)['query'], 'body'
  end

  def test_resolve_refuses_an_unmarked_reply_from_this_account
    github = client(user_response, thread_page(comments: [%w[reviewer Fix], ['justin808', 'Fixed in abc1234.']]))

    error = assert_raises(Shaka::Error) { github.resolve_thread(THREAD) }

    assert_includes error.message, 'shaka reply'
    assert_equal %w[user graphql], paths
  end

  def test_resolve_refuses_a_thread_this_account_only_opened
    github = client(user_response, thread_page(comments: [['justin808', AGENT_REPLY]]))

    error = assert_raises(Shaka::Error) { github.resolve_thread(THREAD) }

    assert_includes error.message, 'replied'
    assert_equal %w[user graphql], paths
  end

  def test_resolve_refuses_a_thread_before_this_account_replied
    github = client(user_response, thread_page(comments: [%w[reviewer Fix], ['teammate', AGENT_REPLY]]))

    error = assert_raises(Shaka::Error) { github.resolve_thread(THREAD) }

    assert_includes error.message, 'replied'
    assert_equal %w[user graphql], paths
  end

  def test_resolve_refuses_an_already_resolved_thread
    github = client(user_response, thread_page(resolved: true))

    error = assert_raises(Shaka::Error) { github.resolve_thread(THREAD) }

    assert_includes error.message, 'already resolved'
    assert_equal %w[user graphql], paths
  end

  def test_resolve_refuses_a_thread_that_is_not_on_the_pull_request
    github = client(user_response, thread_page(id: 'PRRT_other'))

    error = assert_raises(Shaka::Error) { github.resolve_thread(THREAD) }

    assert_includes error.message, 'not on this pull request'
    assert_equal %w[user graphql], paths
  end

  def test_resolve_refuses_when_github_leaves_the_thread_unresolved
    github = client(user_response, thread_page, mutation_response(false))

    error = assert_raises(Shaka::Error) { github.resolve_thread(THREAD) }

    assert_includes error.message, 'did not resolve'
  end

  def test_resolve_refuses_a_malformed_thread_id_before_calling_github
    github = client

    error = assert_raises(Shaka::Error) { github.resolve_thread('not a thread') }

    assert_includes error.message, 'review-thread ID'
    assert_empty @calls
  end

  def test_resolve_refuses_when_reply_evidence_is_incomplete
    github = client(user_response, thread_page(comments: [%w[reviewer Fix]], more_comments: true))

    error = assert_raises(Shaka::Error) { github.resolve_thread(THREAD) }

    assert_includes error.message, 'incomplete'
    assert_equal %w[user graphql], paths
  end

  def test_resolve_command_requires_a_thread_id
    output, status = Open3.capture2e(*SCRIPT, 'resolve', 'owner/repo', '42')

    assert_equal 1, status.exitstatus
    assert_includes output, '--thread'
  end

  private

  def user_response = response({ 'login' => 'justin808' })

  def thread_page(id: THREAD, resolved: false, comments: [%w[reviewer Fix], ['justin808', AGENT_REPLY]],
                  more_comments: false)
    response({ 'data' => { 'repository' => { 'pullRequest' => {
               'reviewThreads' => {
                 'nodes' => [thread_node(id, resolved, comments, more_comments)],
                 'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
               }
             } } } })
  end

  def thread_node(id, resolved, comments, more_comments)
    nodes = comments.map { |login, body| { 'author' => { 'login' => login }, 'body' => body } }
    { 'id' => id, 'isResolved' => resolved,
      'comments' => { 'nodes' => nodes, 'pageInfo' => { 'hasNextPage' => more_comments } } }
  end

  def mutation_response(resolved)
    response({ 'data' => { 'resolveReviewThread' => {
               'thread' => { 'id' => THREAD, 'isResolved' => resolved }
             } } })
  end

  def paths
    @calls.map { |argv, _| argv.drop(2).find { |arg| !arg.start_with?('-') } }
  end

  def sent(index)
    JSON.parse(@calls.fetch(index).last)
  end
end
