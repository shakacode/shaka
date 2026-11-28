# frozen_string_literal: true

require_relative 'handoff_helper'

# #1371: a PR waiting for merge approval must leave that queue while a review thread waits for an answer,
# so a person is not sent to merge past an open finding.
class HandoffMergeWaitThreadsTest < Minitest::Test
  include HandoffHarness

  MERGE = ['awaiting-merge-approval'].freeze

  def withdraws?(result) = result['owed'].any? { |item| item.include?('`attention --state none`') }

  def test_an_unanswered_thread_owes_withdrawing_the_merge_wait
    result = handoff(labels: MERGE, threads: [thread('T1', replies: ['reviewer'])])

    assert_includes result['owed'], 'Reply on review threads waiting for an answer: T1.'
    assert withdraws?(result)
  end

  def test_answered_threads_leave_the_merge_wait_alone
    refute withdraws?(handoff(labels: MERGE, threads: [thread('T1', replies: ['shaka-agent'])]))
  end

  def test_an_unanswered_thread_without_the_merge_wait_owes_only_the_reply
    result = handoff(threads: [thread('T1', replies: ['reviewer'])])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
  end

  # An author `comments` excludes cannot take a PR out of the merge queue by opening a thread.
  def test_a_thread_only_an_excluded_author_opened_keeps_the_merge_wait
    result = handoff(visibility: 'public', labels: MERGE, threads: [thread('T1', opener: 'outsider')])

    refute withdraws?(result)
  end

  def test_a_thread_past_the_first_page_is_not_owed_as_a_withdrawal
    long_thread = thread('T1', replies: ['reviewer'])
    long_thread['comments']['pageInfo']['hasNextPage'] = true

    refute withdraws?(handoff(labels: MERGE, threads: [long_thread]))
  end

  def test_a_trusted_public_author_withdraws_the_merge_wait
    result = handoff(visibility: 'public', trusted: ['reviewer'], labels: MERGE,
                     threads: [thread('T1', opener: 'reviewer')])

    assert withdraws?(result)
  end

  # A permission or trust-settings read that failed is not evidence the author may speak, so the thread
  # stays owed for a reply while the merge wait stands.
  def test_an_unverifiable_public_author_keeps_the_merge_wait
    result = handoff(visibility: 'public', unverifiable: ['outsider'], labels: MERGE,
                     threads: [thread('T1', opener: 'outsider')])

    assert_includes result['owed'], 'Reply on review threads waiting for an answer: T1.'
    refute withdraws?(result)
  end

  def test_unreadable_trusted_actor_settings_keep_the_merge_wait
    result = handoff(visibility: 'public', trust_from_github: true, labels: MERGE,
                     threads: [thread('T1', opener: 'reviewer')])

    assert_includes result['owed'], 'Reply on review threads waiting for an answer: T1.'
    refute withdraws?(result)
  end
end
