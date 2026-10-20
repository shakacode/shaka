# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffWalkthroughTest < Minitest::Test
  include HandoffHarness

  # An answer may change the code, so a walkthrough for an older head waits for it; merge approval still owes one.
  def test_open_decisions_note_an_older_walkthrough_instead_of_owing_one
    asking = description(WIP, 'decisions' => ['Keep the parser?'])
    result = handoff(labels: ['awaiting-answer'], body: asking, reviews: [walkthrough(OLD)])

    assert_empty result['owed']
    assert(result['notes'].any? { |item| item.include?('after the decisions') })
    owed = handoff(labels: ['awaiting-merge-approval'], body: asking, reviews: [walkthrough(OLD)]).fetch('owed')
    assert(owed.any? { |item| item.include?("publish one for #{HEAD}") })
  end

  # `attention --state answer` can set the label with no decisions listed, which holds nothing back.
  def test_the_answer_label_without_listed_decisions_still_owes_a_current_walkthrough
    owed = handoff(labels: ['awaiting-answer'], reviews: [walkthrough(OLD)]).fetch('owed')

    assert(owed.any? { |item| item.include?("publish one for #{HEAD}") })
  end
end
