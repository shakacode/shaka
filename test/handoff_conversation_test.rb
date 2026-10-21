# frozen_string_literal: true

require_relative 'handoff_helper'

# #744: a resumed session must see the conversation comments the PR's person left unanswered.
class HandoffConversationTest < Minitest::Test
  include HandoffHarness

  REPLY = "#{AGENT_POST.lines.first}\nResponded to the [comment](https://github.com/owner/repo/pull/42#issuecomment-%d).".freeze

  def test_the_owners_comment_from_the_agents_account_is_owed
    result = handoff(comments: [comment(11, AGENT_POST), comment(12)])

    assert_includes result['status'], '1 unanswered comment'
    assert_equal ['Reply with `reply` to conversation comments waiting for an answer: ' \
                  'https://github.com/owner/repo/pull/42#issuecomment-12.'], result['owed']
  end

  def test_an_agent_reply_linking_the_comment_answers_it
    assert_empty handoff(comments: [comment(12), comment(13, format(REPLY, 12))])['owed']
    issues_link = format(REPLY, 12).sub('/pull/', '/issues/')

    assert_empty handoff(comments: [comment(12), comment(13, issues_link)])['owed']
  end

  def test_a_later_agent_post_that_does_not_link_the_comment_leaves_it_owed
    result = handoff(comments: [comment(12), comment(13, format(REPLY, 120))])

    assert_equal 1, result['owed'].size
  end

  def test_a_link_from_another_account_or_before_the_comment_does_not_answer_it
    result = handoff(comments: [comment(11, format(REPLY, 12)), comment(12),
                                comment(13, format(REPLY, 12), author: 'outsider')])

    assert_equal 1, result['owed'].size
  end

  def test_the_pr_authors_comment_is_owed_when_another_account_runs_the_agent
    result = handoff(author: 'person', comments: [comment(12, author: 'person')])

    assert_equal 1, result['owed'].size
  end

  def test_bot_and_other_peoples_comments_are_not_owed
    comments = [comment(12, author: 'coderabbitai[bot]'), comment(13, author: 'outsider')]

    assert_empty handoff(comments:)['owed']
  end

  def test_an_unreadable_comment_list_leaves_a_note
    result = handoff(comments: :unreadable)

    assert_empty result['owed']
    assert_includes result['notes'], 'Conversation comments are unread: Comment listing response is malformed.'
  end
end
