# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

# A click on GitHub's merge queue writes the repository default, so doctor says when that default
# copies the whole PR description, WIP Details included, into git history.
class DoctorMergeQueueTest < Minitest::Test
  include DoctorHelper

  def queue_answer(body)
    repository = { 'squashMergeCommitTitle' => 'PR_TITLE', 'squashMergeCommitMessage' => body,
                   'mergeQueue' => { 'configuration' => { 'mergeMethod' => 'SQUASH' } } }
    [JSON.generate('data' => { 'repository' => repository }), '', true]
  end

  def test_a_queue_that_copies_the_description_is_degraded_with_both_ways_out
    report, blocked = doctor(responses: { queue: queue_answer('PR_BODY') })

    assert_includes report, '[DEGRADED] Merge queue commits — adding a PR to the merge queue on GitHub copies'
    assert_includes report, 'Ask Shaka to merge'
    assert_includes report, 'Allow squash merging (`squash_merge_commit_message`) to Pull request title'
    refute blocked
  end

  def test_a_queue_that_leaves_the_description_out_is_healthy
    report, = doctor(responses: { queue: queue_answer('COMMIT_MESSAGES') })

    assert_includes report, '[HEALTHY] Merge queue commits — the merge queue leaves the PR description out of commits'
  end

  def test_no_queue_is_healthy
    report, = doctor

    assert_includes report, '[HEALTHY] Merge queue commits — the default branch has no merge queue'
  end

  def test_unread_queue_defaults_are_named_rather_than_passed
    report, = doctor(responses: { queue: ['', 'HTTP 403', false] })
    assert_includes report, '[DEGRADED] Merge queue commits — not checked: HTTP 403'

    report, = doctor(responses: { queue: queue_answer(nil) })
    assert_includes report, "could not read the queue's commit defaults"
  end
end
