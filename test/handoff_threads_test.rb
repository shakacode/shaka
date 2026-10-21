# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffThreadsTest < Minitest::Test
  include HandoffHarness

  def test_an_answered_open_thread_is_not_owed
    result = handoff(threads: [thread('T1', replies: ['shaka-agent'])])

    assert_empty result['owed']
    assert_empty result['notes']
  end

  def test_an_unanswered_open_thread_is_owed
    result = handoff(threads: [thread('T1', replies: ['someone-else']), thread('T2', replies: ['shaka-agent'])])

    assert_includes result['status'], '1 unanswered thread'
    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
  end

  def test_a_thread_the_agent_opened_is_not_owed
    assert_empty handoff(threads: [thread('T1', opener: 'shaka-agent')])['owed']
  end

  # #744: the agent posts from the person's account, so the account cannot tell their threads apart.
  def test_a_thread_the_person_opened_from_the_agents_account_is_owed
    result = handoff(threads: [thread('T1', opener: ['shaka-agent', 'Rename this.'])])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
  end

  def test_a_persons_comment_after_the_agents_answer_is_owed
    threads = [thread('T1', replies: %w[shaka-agent reviewer]),
               thread('T2', replies: ['shaka-agent', ['shaka-agent', 'One more thing.']])]

    assert_equal ['Reply on review threads waiting for an answer: T1, T2.'], handoff(threads:)['owed']
  end

  def test_a_bots_comment_after_the_agents_answer_is_not_owed
    assert_empty handoff(threads: [thread('T1', replies: ['shaka-agent', 'coderabbitai[bot]'])])['owed']
  end

  def test_a_bots_thread_without_an_answer_is_owed
    result = handoff(threads: [thread('T1', opener: 'coderabbitai[bot]')])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
  end

  def test_an_agent_line_from_another_account_neither_answers_nor_clears_a_thread
    threads = [thread('T1', replies: [['outsider', HandoffFixtures::AGENT_POST]]),
               thread('T2', replies: ['shaka-agent', 'reviewer', ['outsider', HandoffFixtures::AGENT_POST]])]

    assert_equal ['Reply on review threads waiting for an answer: T1, T2.'], handoff(threads:)['owed']
  end

  def test_a_truncated_thread_is_noted_even_when_its_first_page_ends_with_an_answer
    long_thread = thread('T1', replies: ['shaka-agent'])
    long_thread['comments']['pageInfo']['hasNextPage'] = true
    result = handoff(threads: [long_thread], labels: ['awaiting-merge-approval'])

    refute(result['owed'].any? { |item| item.include?('review threads') })
    assert_includes result['notes'], 'Check by hand for a comment past 100 on T1.'
    refute(result['notes'].any? { |item| item.include?('answered review thread') })
  end

  def test_an_app_account_matches_only_its_own_bot_comments
    answered = thread('T1', replies: ['shaka-agent[bot]'])
    namesake = thread('T2', replies: ['shaka-agent'])
    result = handoff(viewer: 'shaka-agent[bot]', threads: [answered, namesake])

    assert_equal ['Reply on review threads waiting for an answer: T2.'], result['owed']
  end

  def test_a_resolved_thread_without_a_reply_is_not_owed
    assert_empty handoff(threads: [thread('T1', resolved: true)])['owed']
  end

  def test_a_replied_thread_left_open_is_counted_only_for_merge_approval
    threads = [thread('T1', replies: ['shaka-agent']), thread('T2', replies: ['shaka-agent'])]
    labels = ['awaiting-merge-approval']

    assert_empty handoff(threads:)['notes']
    result = handoff(threads:, labels:)

    assert_includes result['notes'], '2 answered review threads still open; confirm each is meant to stay open.'
    refute(result['owed'].any? { |item| item.include?('review threads') })
  end

  def test_an_unreadable_thread_list_leaves_a_note_and_the_rest_of_the_report
    result = handoff(threads: :unreadable)

    assert_empty result['owed']
    assert_includes result['notes'], 'Review threads are unread: GraphQL failed or returned missing data.'
    assert_includes result['status'], "walkthrough #{HEAD[0, 7]} · WIP #{HEAD[0, 7]}"
  end

  def test_a_thread_whose_reply_may_be_past_the_first_page_is_noted_not_owed
    long_thread = thread('T1', replies: ['someone-else'])
    long_thread['comments']['pageInfo']['hasNextPage'] = true
    result = handoff(threads: [long_thread])

    assert_empty result['owed']
    assert_includes result['notes'], 'Check by hand for a comment past 100 on T1.'
  end
end
