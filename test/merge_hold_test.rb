# frozen_string_literal: true

require_relative 'merge_test'
require 'shaka/merge_hold'
require 'shaka/repository_config'
require_relative 'repository_fixture'

# A maintainer's hold label stops every merge Shaka submits, and no confirmation passes it.
class MergeHoldTest < Minitest::Test
  include MergeFixtures

  def labeled(*names, total: names.length)
    snapshot.merge('labels' => { 'totalCount' => total, 'nodes' => names.map { |name| { 'name' => name } } })
  end

  def test_a_hold_label_refuses_the_merge_naming_the_label
    @client.snapshots = [labeled('bug', 'Hold')]

    assert_blocked(/hold label "Hold" \(merge\.hold_labels\); hand it to the user as Ask/)
  end

  def test_other_labels_merge
    @client.snapshots = [labeled('bug', 'awaiting-merge-approval')]

    assert @merge.call(head: HEAD, base: BASE, walkthrough: 17).fetch('merged')
  end

  def test_a_label_added_while_gates_are_read_stops_the_submission
    @client.snapshots = [labeled, labeled('hold')]

    assert_blocked(/hold label "hold"/)
  end

  def test_limit_and_floor_confirmations_do_not_pass_a_hold
    @merge.review_floor = Shaka::MergeReviewFloor.new(2, confirmed_head: HEAD)
    @client.snapshots = [labeled('hold')]
    error = assert_raises(Shaka::Error) do
      @merge.call(head: HEAD, base: BASE, walkthrough: 17, limits: Shaka::MergeLimits.new(confirmed_head: HEAD))
    end

    assert_match(/hold label/, error.message)
    assert_empty @client.mutations
  end

  def test_an_incomplete_or_missing_label_list_refuses
    [labeled(*Array.new(100) { |n| "l#{n}" }, total: 101), snapshot.except('labels')].each do |pull|
      @client.snapshots = [pull]

      assert_blocked(/complete label list to check merge\.hold_labels/)
    end
  end

  def test_a_repository_chooses_its_own_hold_labels
    @merge.hold = Shaka::MergeHold.new(['do-not-merge'])
    @client.snapshots = [labeled('DO-NOT-MERGE')]
    assert_blocked(/hold label "DO-NOT-MERGE"/)

    @client.snapshots = [labeled('hold')]
    assert @merge.call(head: HEAD, base: BASE, walkthrough: 17).fetch('merged')
  end
end

# merge.hold_labels defaults to [hold] and takes a list of label names.
class MergeHoldSettingTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def labels(merge = {})
    with_repository('merge' => { 'preference' => 'ask' }.merge(merge)) do |root|
      return Shaka::MergeHold.from(Shaka::RepositoryConfig.load(root:)).labels
    end
  end

  def test_defaults_to_hold
    assert_equal ['hold'], labels
    assert_equal ['hold'], Shaka::MergeHold.from(nil).labels
  end

  def test_a_repository_can_set_its_labels
    assert_equal %w[hold wip], labels('hold_labels' => %w[hold wip])
  end

  def test_rejects_an_empty_or_malformed_list
    [[], 'hold', [1], %w[hold HOLD]].each do |value|
      error = assert_raises(Shaka::Error) { labels('hold_labels' => value) }

      assert_includes error.message, 'merge.hold_labels'
    end
  end
end
