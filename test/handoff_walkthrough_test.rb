# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffWalkthroughTest < Minitest::Test
  include HandoffHarness

  # An answer may change the code, so a walkthrough for an older head waits for the listed decisions.
  def test_listed_decisions_note_an_older_walkthrough_instead_of_owing_one
    asking = description(WIP, 'decisions' => ['Keep the parser?'])
    %w[awaiting-answer awaiting-resume].each do |label|
      result = handoff(labels: [label], body: asking, reviews: [walkthrough(OLD)])

      assert_empty result['owed'], label
      assert(result['notes'].any? { |item| item.include?('after the decisions') }, label)
    end
  end

  def test_merge_approval_owes_a_current_walkthrough_even_with_listed_decisions
    asking = description(WIP, 'decisions' => ['Keep the parser?'])
    owed = handoff(labels: ['awaiting-merge-approval'], body: asking, reviews: [walkthrough(OLD)]).fetch('owed')

    assert(owed.any? { |item| item.include?("publish one for #{HEAD}") })
  end

  # `attention --state answer` can set the label with no decisions listed, which holds nothing back.
  def test_the_answer_label_without_listed_decisions_still_owes_a_current_walkthrough
    owed = handoff(labels: ['awaiting-answer'], reviews: [walkthrough(OLD)]).fetch('owed')

    assert(owed.any? { |item| item.include?("publish one for #{HEAD}") })
  end

  PENDING = { 'id' => 9, 'state' => 'PENDING', 'user' => { 'login' => 'shaka-agent' } }.freeze

  # The maintainer's unsubmitted review is visible only to them, so handoff asks for it through awaiting-answer.
  def test_an_unsubmitted_review_owes_the_answer_label_and_names_the_review
    result = handoff(reviews: [walkthrough(HEAD), PENDING])

    assert_includes result['status'], 'unsubmitted review'
    asked = result['owed'].find { |item| item.include?(Shaka::PendingReview::MESSAGE) }
    assert_includes asked, 'awaiting-answer'
  end

  def test_an_unsubmitted_review_with_the_answer_label_owes_nothing_and_holds_the_walkthrough
    result = handoff(labels: ['awaiting-answer'], reviews: [walkthrough(OLD), PENDING])

    assert_empty result['owed']
    assert_includes result['status'], 'awaiting-answer for unsubmitted review'
    assert_includes result['notes'], Shaka::PendingReview::MESSAGE
  end

  # Only the review's author can submit it, so a wake source cannot stand in for the label.
  def test_an_unsubmitted_review_still_owes_the_label_when_something_wakes_the_agent
    owed = handoff(labels: [], woken_by: 'pr watch', reviews: [walkthrough(HEAD), PENDING]).fetch('owed')

    assert(owed.any? { |item| item.include?(Shaka::PendingReview::MESSAGE) })
  end

  def test_another_accounts_pending_review_changes_nothing
    other = PENDING.merge('user' => { 'login' => 'someone-else' })
    result = handoff(reviews: [walkthrough(HEAD), other])

    assert_empty result['owed']
    refute_includes result['status'], 'unsubmitted review'
  end

  # GitHub would refuse the new walkthrough a merge wait owes, so that wait gives way to the answer.
  def test_an_unsubmitted_review_on_a_merge_wait_with_an_old_walkthrough_owes_the_answer_label
    owed = handoff(labels: ['awaiting-merge-approval'], reviews: [walkthrough(OLD), PENDING]).fetch('owed')

    asked = owed.find { |item| item.include?(Shaka::PendingReview::MESSAGE) }
    assert_includes asked, '`attention --state answer` first'
  end

  # A merge needs no new review, so a recorded merge wait keeps its label and only names the draft.
  def test_an_unsubmitted_review_leaves_a_ready_merge_wait_in_place
    result = handoff(labels: ['awaiting-merge-approval'], reviews: [walkthrough(HEAD), PENDING])

    refute(result['owed'].any? { |item| item.include?(Shaka::PendingReview::MESSAGE) })
    assert_includes result['status'], 'awaiting-merge-approval'
    assert_includes result['notes'], Shaka::PendingReview::MESSAGE
  end
end
