# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'shaka/public_comments/fetch_guard'

class CommentFetchGuardTest < Minitest::Test
  HOOK = File.expand_path('../skills/shaka/scripts/cursor-comment-hook', __dir__)

  DENIED = [
    'gh api repos/shakacode/shaka/pulls/165/comments',
    'gh api --paginate repos/shakacode/shaka/pulls/165/comments',
    'gh api /repos/shakacode/shaka/issues/77/comments',
    'gh api repos/shakacode/shaka/pulls/comments/4058209763',
    'gh api repos/shakacode/shaka/issues/comments/12',
    'gh api repos/shakacode/shaka/pulls/165/reviews',
    'gh api repos/shakacode/shaka/pulls/165/reviews/9/comments',
    'gh pr view 165 --comments',
    'gh issue view 77 --comments',
    'gh pr view 165 --json comments,title',
    'gh pr view 165 --json=reviews',
    'curl -s https://api.github.com/repos/shakacode/shaka/pulls/165/comments',
    %(gh api graphql -f query='query { reviews { nodes { body } } }'),
    'gh api graphql --input -',
    'gh api graphql -F query=@query.graphql'
  ].freeze

  ALLOWED = [
    'gh pr checks 190',
    'gh pr view 190 --json title,state,statusCheckRollup',
    'gh api repos/shakacode/shaka/pulls/190',
    'gh api repos/shakacode/shaka/issues/77',
    'gh api repos/shakacode/shaka/contents/graphql',
    'shaka comments shakacode/shaka 190 --head abcdef',
    'git commit -m "mention comments"',
    %(gh api graphql -f query='query { reviewThreads { nodes { comments { nodes { fullDatabaseId } } } } }')
  ].freeze

  def test_known_comment_reads_are_denied
    DENIED.each { |command| assert Shaka::PublicComments::FetchGuard.denied?(command), command }
  end

  def test_ordinary_github_commands_are_allowed
    ALLOWED.each { |command| refute Shaka::PublicComments::FetchGuard.denied?(command), command }
  end

  def test_the_hook_denies_a_comment_list_and_allows_a_pull_request_view
    assert_equal 'deny', hook('gh api repos/o/r/pulls/1/comments')['permission']
    assert_equal 'allow', hook('gh pr view 1 --json title')['permission']
  end

  def test_the_hook_denies_input_that_is_not_json
    result, = Open3.capture2(HOOK, stdin_data: '{')
    assert_equal 'deny', JSON.parse(result)['permission']
  end

  private

  def hook(command)
    stdout, = Open3.capture2(HOOK, stdin_data: JSON.generate('command' => command))
    JSON.parse(stdout)
  end
end
