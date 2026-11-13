# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffApprovalHoldTest < Minitest::Test
  include HandoffHarness

  HELD = { 'name' => 'deploy', 'state' => 'WAITING', 'bucket' => 'pending',
           'link' => 'https://github.com/owner/repo/actions/runs/7' }.freeze

  # A check waiting on a deployment approval never finishes, so no monitor that waits for checks will fire.
  def test_a_wake_source_does_not_cover_a_check_held_for_approval
    result = handoff(labels: [], woken_by: 'host PR monitor', checks: [HELD])

    assert_includes result['status'], 'blocked (approval hold): deploy'
    owed = result['owed'].join("\n")
    assert_includes owed, 'deploy waits on a manual approval'
    assert_includes owed, HELD['link']
  end

  # The label the approval item asks for must not also be owed for removal.
  def test_a_held_check_keeps_the_label_rule_beside_a_wake_source
    result = handoff(labels: ['awaiting-resume'], woken_by: 'host PR monitor', checks: [HELD])

    assert_equal 1, result['owed'].size
    assert_includes result['owed'].first, 'deploy waits on a manual approval'
    assert_includes result['status'], 'awaiting-resume'
  end

  # The REST reader reports a missing link as an empty string.
  def test_a_held_check_without_a_link_names_its_workflow_run
    result = handoff(labels: ['awaiting-resume'], checks: [HELD.merge('link' => '')])

    assert(result['notes'].any? { |note| note.end_with?('approve it at its workflow run.') })
  end

  def test_a_labeled_pr_with_a_held_check_names_the_approval_without_owing_it
    result = handoff(labels: ['awaiting-resume'], checks: [HELD])

    assert_empty result['owed']
    assert(result['notes'].any? { |note| note.include?('deploy waits on a manual approval') })
  end
end
