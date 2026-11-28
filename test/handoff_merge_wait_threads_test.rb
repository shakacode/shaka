# frozen_string_literal: true

require_relative 'handoff_helper'

# #1371: a PR waiting for merge approval must leave that queue while a review thread waits for an answer,
# so a person is not sent to merge past an open finding.
class HandoffMergeWaitThreadsTest < Minitest::Test
  include HandoffHarness

  MERGE = ['awaiting-merge-approval'].freeze
  WITHDRAW = 'Review threads wait for an answer while awaiting-merge-approval is set: run ' \
             '`attention --state none` and withdraw the merge-ready handoff in WIP Details before working on them.'

  def test_an_unanswered_thread_owes_withdrawing_the_merge_wait
    result = handoff(labels: MERGE, threads: [thread('T1', replies: ['reviewer'])])

    assert_includes result['owed'], 'Reply on review threads waiting for an answer: T1.'
    assert_includes result['owed'], WITHDRAW
  end

  def test_answered_threads_leave_the_merge_wait_alone
    refute_includes handoff(labels: MERGE, threads: [thread('T1', replies: ['shaka-agent'])])['owed'], WITHDRAW
  end

  def test_an_unanswered_thread_without_the_merge_wait_owes_only_the_reply
    result = handoff(threads: [thread('T1', replies: ['reviewer'])])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
  end

  # An author `comments` excludes cannot take a PR out of the merge queue by opening a thread.
  def test_a_thread_only_an_excluded_author_opened_keeps_the_merge_wait
    result = handoff(visibility: 'public', labels: MERGE, threads: [thread('T1', opener: 'outsider')])

    refute_includes result['owed'], WITHDRAW
  end

  def test_a_thread_past_the_first_page_is_not_owed_as_a_withdrawal
    long_thread = thread('T1', replies: ['reviewer'])
    long_thread['comments']['pageInfo']['hasNextPage'] = true

    refute_includes handoff(labels: MERGE, threads: [long_thread])['owed'], WITHDRAW
  end
end
