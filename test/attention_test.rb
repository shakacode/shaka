# frozen_string_literal: true

require_relative 'github_helper'
require 'shaka/attention'

class AttentionTest < Minitest::Test
  include GitHubHelper

  LABELS_PATH = 'repos/owner/repo/issues/42/labels'

  def labels_response(*names)
    response(names.map { |name| { 'name' => name } })
  end

  def call(state, *responses)
    Shaka::Attention.new(client(*responses)).call(state: state)
  end

  def requests
    @calls.map { |argv, input| [argv[2], argv[argv.index('--method') + 1], input] }
  end

  def test_answer_replaces_merge_approval_with_one_label
    result = call('answer', snapshot_response, labels_response('bug', 'awaiting-merge-approval'),
                  labels_response('bug'), labels_response('bug', 'awaiting-answer'))

    assert_equal({ 'state' => 'answer', 'labels' => ['awaiting-answer'] }, result)
    assert_equal ["#{LABELS_PATH}/awaiting-merge-approval", 'DELETE'], requests[2].first(2)
    assert_equal [LABELS_PATH, 'POST', JSON.generate(labels: ['awaiting-answer'])], requests[3]
  end

  def test_merge_keeps_an_existing_label_without_writing
    result = call('merge', snapshot_response, labels_response('awaiting-merge-approval'))

    assert_equal({ 'state' => 'merge', 'labels' => ['awaiting-merge-approval'] }, result)
    assert_equal 2, @calls.length
  end

  def test_none_clears_both_labels_even_after_the_pr_closes
    result = call('none', labels_response('awaiting-answer', 'awaiting-merge-approval', 'bug'),
                  labels_response('awaiting-merge-approval', 'bug'), labels_response('bug'))

    assert_equal({ 'state' => 'none', 'labels' => [] }, result)
    assert_equal(%w[GET DELETE DELETE], requests.map { |request| request[1] })
  end

  def test_setting_a_label_requires_an_open_pull_request
    error = assert_raises(Shaka::Error) { call('merge', snapshot_response(state: 'MERGED')) }

    assert_match(/not open/, error.message)
    assert_equal 1, @calls.length
  end

  def test_rejects_an_unknown_state_before_any_request
    assert_raises(Shaka::Error) { call('approved') }
    assert_empty @calls
  end
end
