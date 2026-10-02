# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github'
require 'shaka/local_review'

module BotReviewHistoryFixture
  HEAD = 'a' * 40

  Reader = Struct.new(:packet) do
    def call(expected_head:)
      raise 'Unexpected head' unless expected_head == packet['head']

      packet
    end
  end

  class GitHub < Shaka::GitHub
    attr_reader :writes, :node
    attr_accessor :head, :permission, :mismatch, :failure, :changed, :moved

    def initialize
      super('example/test', 1)
      @head = HEAD
      @permission = true
      @writes = []
      @node = { '__typename' => 'IssueComment', 'id' => 'IC_1', 'databaseId' => 1,
                'url' => 'https://github.com/example/test/pull/1#issuecomment-1',
                'body' => 'Earlier review findings', 'isMinimized' => false,
                'minimizedReason' => nil, 'viewerCanMinimize' => true,
                'author' => { '__typename' => 'Bot', 'login' => 'claude' } }
    end

    def snapshot = { 'state' => 'OPEN', 'headRefOid' => head }

    def api(_path, **_options) = { 'node_id' => node['id'] }

    def graphql(query, **_variables)
      raise Shaka::Error, 'Permission denied' if failure

      return { 'node' => node.merge('viewerCanMinimize' => permission) } unless query.include?('mutation')

      minimize
    end

    def minimize
      @writes << node['id']
      node.merge!('isMinimized' => true, 'minimizedReason' => 'outdated') unless mismatch
      node['body'] += ' changed' if changed
      @head = 'b' * 40 if moved
      { 'minimizeComment' => { 'minimizedComment' => node.dup } }
    end
  end

  def setup
    @github = GitHub.new
    @row = { 'id' => 1, 'url' => @github.node['url'], 'author' => 'claude[bot]',
             'body' => @github.node['body'], 'trust' => 'configured_bot' }
  end

  def collapse(ids = [1], rows: [@row])
    packet = { 'head' => HEAD, 'issue_comments' => rows }
    Shaka::BotReviewHistory.new(@github, reader: Reader.new(packet)).collapse(ids, head: HEAD)
  end
end

class BotReviewHistoryTest < Minitest::Test
  include BotReviewHistoryFixture

  def test_minimizes_selected_bot_report_without_rewriting_findings
    result = collapse
    assert_equal [1], result['collapsed']
    assert_empty result['unavailable']
    assert_equal ['IC_1'], @github.writes
    assert_equal 'Earlier review findings', @github.node['body']
    assert_equal 'outdated', @github.node['minimizedReason']
  end

  def test_repeat_run_preserves_existing_minimization_reason
    @github.node.merge!('isMinimized' => true, 'minimizedReason' => 'resolved')
    assert_equal [1], collapse['already_minimized']
    assert_empty @github.writes
    assert_equal 'resolved', @github.node['minimizedReason']
  end

  def test_large_comment_identifiers_need_no_graphql_numeric_field
    @row['id'] = 5_908_851_946
    @row['url'] = @github.node['url'] = 'https://github.com/example/test/pull/1#issuecomment-5908851946'
    @github.node.delete('databaseId')
    assert_equal [5_908_851_946], collapse([5_908_851_946])['collapsed']
  end

  def test_selected_withheld_or_foreign_comment_does_not_write
    result = collapse(rows: [])
    assert_match(/not admitted/, result['unavailable'].first)
    assert_empty @github.writes
  end

  def test_human_with_bot_like_login_is_not_minimized
    @github.node['author']['__typename'] = 'User'
    assert_match(/not the admitted bot/, collapse['unavailable'].first)
    assert_empty @github.writes
  end

  def test_changed_content_or_wrong_pr_url_is_not_minimized
    @row['body'] = 'Previous text'
    assert_equal 1, collapse['unavailable'].size
    @row['body'] = @github.node['body']
    @github.node['url'] = 'https://github.com/example/test/pull/2#issuecomment-1'
    assert_equal 1, collapse['unavailable'].size
    assert_empty @github.writes
  end

  def test_moved_head_is_not_minimized
    @github.head = 'b' * 40
    assert_match(/head changed/, collapse['unavailable'].first)
    assert_empty @github.writes
  end

  def test_head_change_after_confirmed_write_keeps_the_edit_and_reports_the_race
    @github.moved = true
    result = collapse
    assert_equal [1], result['collapsed']
    assert_match(/head changed/, result['unavailable'].first)
    assert_equal ['IC_1'], @github.writes
    assert_equal 'outdated', @github.node['minimizedReason']
  end

  def test_permission_failure_is_visible
    @github.permission = false
    assert_match(/does not permit/, collapse['unavailable'].first)
    assert_empty @github.writes
  end

  def test_api_failure_is_visible
    @github.failure = true
    assert_match(/Permission denied/, collapse['unavailable'].first)
    assert_empty @github.writes
  end

  def test_unconfirmed_write_is_not_reported_as_collapsed
    @github.mismatch = true
    result = collapse
    assert_empty result['collapsed']
    assert_match(/did not confirm/, result['unavailable'].first)
  end

  def test_changed_body_after_write_is_reported_without_rewriting_it
    @github.changed = true
    assert_match(/content changed/, collapse['unavailable'].first)
    assert_equal ['IC_1'], @github.writes
    assert_equal 'Earlier review findings changed', @github.node['body']
  end

  def test_partial_failure_retains_success_and_duplicate_selection_writes_once
    result = collapse([2, 1, 1])
    assert_equal [1], result['collapsed']
    assert_equal 1, result['unavailable'].size
    assert_equal ['IC_1'], @github.writes
  end
end

class BotReviewHistoryCliTest < Minitest::Test
  def test_bot_selection_requires_a_full_expected_head
    assert_raises(OptionParser::MissingArgument) do
      Shaka::LocalReviewHistory.run(['example/test', '1', '--bot-comment', '1'])
    end
    assert_raises(OptionParser::InvalidArgument) do
      Shaka::LocalReviewHistory.run(['example/test', '1', '--bot-comment', '1', '--head', 'short'])
    end
  end

  def test_selection_rejects_nonpositive_identifiers
    assert_raises(OptionParser::InvalidArgument) do
      Shaka::LocalReviewHistory.run(['example/test', '1', '--bot-comment', '-1'])
    end
  end
end
