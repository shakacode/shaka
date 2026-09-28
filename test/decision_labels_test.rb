# frozen_string_literal: true

require_relative 'github_helper'
require 'shaka/decision_labels'

class DecisionLabelsTest < Minitest::Test
  include GitHubHelper

  LABELS_PATH = 'repos/owner/repo/issues/42/labels'
  FIRST_PAGE = "#{LABELS_PATH}?per_page=100&page=1".freeze

  def labels_response(*names)
    response(names.map { |name| { 'name' => name } })
  end

  def label_exists = response({ 'name' => 'existing' })

  def requests
    @calls.map { |argv, input| [argv[2], argv[argv.index('--method') + 1], input] }
  end

  def test_a_missing_decisions_key_leaves_labels_alone
    result = Shaka::DecisionLabels.sync(client, {})

    assert_nil result
    assert_empty @calls
  end

  def test_a_non_empty_list_applies_awaiting_answer
    github = client(snapshot_response, labels_response('bug'), label_exists, labels_response('bug', 'awaiting-answer'))
    result = Shaka::DecisionLabels.sync(github, { 'decisions' => ['Keep the label?'] })

    assert_equal({ 'state' => 'answer', 'labels' => ['awaiting-answer'] }, result)
    assert_equal [LABELS_PATH, 'POST', JSON.generate(labels: ['awaiting-answer'])], requests.last
  end

  def test_a_non_empty_list_refuses_to_replace_awaiting_merge_approval
    github = client(snapshot_response, labels_response('awaiting-merge-approval'))
    error = assert_raises(Shaka::Error) do
      Shaka::DecisionLabels.sync(github, { 'decisions' => ['Keep the label?'] })
    end

    assert_includes error.message, 'awaiting-merge-approval'
    writes = requests.reject { |path, method, _input| method == 'GET' || path.include?('graphql') }
    assert_empty writes
  end

  def test_an_empty_list_removes_only_awaiting_answer
    github = client(labels_response('awaiting-answer', 'awaiting-merge-approval'),
                    labels_response('awaiting-merge-approval'))
    result = Shaka::DecisionLabels.sync(github, { 'decisions' => [] })

    assert_equal({ 'state' => 'released', 'labels' => ['awaiting-merge-approval'] }, result)
    assert_equal ["#{LABELS_PATH}/awaiting-answer", 'DELETE'], requests[1].first(2)
    assert_equal 2, requests.length
  end

  def test_an_empty_list_does_not_write_when_the_label_is_absent
    github = client(labels_response('awaiting-resume'))
    result = Shaka::DecisionLabels.sync(github, { 'decisions' => [] })

    assert_equal({ 'state' => 'released', 'labels' => ['awaiting-resume'] }, result)
    assert_equal([[FIRST_PAGE, 'GET']], requests.map { |request| request.first(2) })
  end

  def test_decisions_must_be_a_list
    assert_raises(Shaka::Error) { Shaka::DecisionLabels.sync(client, { 'decisions' => 'Keep the label?' }) }
    assert_empty @calls
  end
end
