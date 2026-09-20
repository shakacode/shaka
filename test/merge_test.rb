# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/merge'

module MergeFixtures
  HEAD = 'a' * 40

  class Client
    attr_accessor :snapshots, :checks, :review_result, :mutation_result, :mutation_error
    attr_reader :mutations, :requested_review, :features

    def initialize
      @mutations = []
      @features = []
    end

    def snapshot
      value = snapshots.length > 1 ? snapshots.shift : snapshots.first
      raise value if value.is_a?(Exception)

      value
    end

    def required_checks
      raise checks if checks.is_a?(Exception)

      checks
    end

    def review(id)
      @requested_review = id
      raise review_result if review_result.is_a?(Exception)

      review_result
    end

    def graphql(query, variables, feature: nil)
      @mutations << [query, variables]
      @features << feature
      raise mutation_error if mutation_error

      mutation_result
    end
  end

  def setup
    @client = Client.new
    @client.snapshots = [snapshot]
    @client.checks = [{ 'name' => 'Validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
    @client.review_result = { 'id' => 17, 'commit_id' => HEAD, 'state' => 'COMMENTED', 'body' => 'Walkthrough' }
    @client.mutation_result = { 'mergePullRequest' => { 'pullRequest' => {
      'headRefOid' => HEAD, 'state' => 'MERGED', 'merged' => true, 'mergeCommit' => { 'oid' => 'b' * 40 }
    } } }
    @merge = Shaka::Merge.new(@client)
  end

  def snapshot
    { 'id' => 'PR_123', 'headRefOid' => HEAD, 'baseRefName' => 'main', 'state' => 'OPEN', 'isDraft' => false,
      'viewerCanMergeAsAdmin' => false, 'isMergeQueueEnabled' => false, 'isInMergeQueue' => false,
      'mergeQueueEntry' => nil,
      'autoMergeRequest' => nil, 'mergeStateStatus' => 'CLEAN', 'reviewDecision' => nil }
  end

  def assert_blocked(pattern)
    error = assert_raises(Shaka::Error) { @merge.call(head: HEAD, walkthrough: 17) }
    assert_match pattern, error.message
    assert_empty @client.mutations
  end

  def queue_entry(head: HEAD, position: nil)
    { 'id' => 'MQE_123', 'position' => position, 'state' => 'AWAITING_CHECKS',
      'headCommit' => { 'oid' => head }, 'baseCommit' => { 'oid' => 'd' * 40 } }.compact
  end

  def assert_queue_result(result, entry)
    assert_equal 'merge_queue', result.fetch('submission')
    assert_equal HEAD, result.fetch('headRefOid')
    assert_equal entry, result.fetch('mergeQueueEntry')
  end
end

class MergeNativeGateTest < Minitest::Test
  include MergeFixtures

  def test_refuses_a_draft_or_closed_pull_request
    [{ 'isDraft' => true }, { 'state' => 'CLOSED' }].each do |changes|
      @client.snapshots = [snapshot.merge(changes)]
      assert_blocked(/open and not a draft/)
    end
  end

  def test_refuses_stale_or_unknown_merge_state
    %w[BEHIND BLOCKED DIRTY DRAFT HAS_HOOKS UNKNOWN UNSTABLE].each do |state|
      @client.snapshots = [snapshot.merge('mergeStateStatus' => state)]
      assert_blocked(/not CLEAN/)
    end
  end

  def test_refuses_bypass_capable_or_unknown_actor
    [true, nil].each do |value|
      @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => value)]
      assert_blocked(/protection must be enforced/)
    end
  end

  def test_refuses_unknown_queue_state
    %w[isMergeQueueEnabled isInMergeQueue].each do |key|
      [nil].each do |value|
        @client.snapshots = [snapshot.merge(key => value)]
        assert_blocked(/queue state is unknown/)
      end
    end
  end

  def test_refuses_a_queue_entry_when_github_reports_not_queued
    @client.snapshots = [snapshot.merge('mergeQueueEntry' => { 'id' => 'MQE_123' })]

    assert_blocked(/queue state is inconsistent/)
  end

  def test_refuses_existing_or_unknown_delayed_auto_merge
    @client.snapshots = [snapshot.merge('autoMergeRequest' => { 'enabledAt' => '2026-09-14T00:00:00Z' })]
    assert_blocked(/delayed auto-merge/)
    @client.snapshots = [snapshot.except('autoMergeRequest')]
    assert_blocked(/delayed auto-merge/)
  end

  def test_missing_required_approval_or_changes_requested_blocks
    %w[REVIEW_REQUIRED CHANGES_REQUESTED FUTURE_STATE].each do |state|
      @client.snapshots = [snapshot.merge('reviewDecision' => state)]
      assert_blocked(/Required reviews/)
    end
    @client.snapshots = [snapshot.except('reviewDecision')]
    assert_blocked(/Required reviews/)
  end
end

class MergeCheckTest < Minitest::Test
  include MergeFixtures

  def test_accepts_github_terminal_check_conclusions
    @client.checks = [%w[SUCCESS pass], %w[NEUTRAL skipping], %w[SKIPPED skipping]].map do |state, bucket|
      { 'name' => state, 'state' => state, 'bucket' => bucket }
    end
    assert_equal 'MERGED', @merge.call(head: HEAD, walkthrough: 17)['state']
  end

  def test_empty_or_unknown_check_list_blocks
    [[], nil, {}].each do |checks|
      @client.checks = checks
      assert_blocked(/No observable required checks/)
    end
  end

  def test_failed_pending_cancelled_or_unknown_checks_block
    %w[FAILURE ERROR PENDING IN_PROGRESS CANCELLED TIMED_OUT EXPECTED FUTURE_STATE].each do |state|
      @client.checks = [{ 'name' => 'Validate', 'state' => state, 'bucket' => 'pass' }]
      assert_blocked(/Required check/)
    end
  end

  def test_inconsistent_or_malformed_check_results_block
    [nil, 'success', {}, { 'state' => 'SUCCESS', 'bucket' => 'pass' },
     { 'name' => 'Validate', 'state' => 'SUCCESS', 'bucket' => 'pending' },
     { 'name' => 'Validate', 'state' => 'SKIPPED', 'bucket' => 'pass' }].each do |check|
      @client.checks = [check]
      assert_blocked(/Required check/)
    end
  end

  def test_api_failure_does_not_submit
    @client.checks = Shaka::Error.new('GitHub unavailable')
    assert_blocked(/GitHub unavailable/)
  end
end

class MergeWalkthroughTest < Minitest::Test
  include MergeFixtures

  def test_wrong_review_id_or_head_blocks
    [{ 'id' => 99 }, { 'commit_id' => 'c' * 40 }].each do |changes|
      @client.review_result = { 'id' => 17, 'commit_id' => HEAD }.merge(changes)
      assert_blocked(/review on this PR at the expected head/)
    end
  end

  def test_missing_review_on_this_pull_request_blocks
    @client.review_result = Shaka::Error.new('Review not found on this PR')
    assert_blocked(/not found on this PR/)
  end

  def test_pending_approving_or_blank_reviews_do_not_count_as_walkthroughs
    [{ 'state' => 'PENDING' }, { 'state' => 'APPROVED' }, { 'body' => '  ' }, { 'body' => nil }].each do |changes|
      @client.review_result = { 'id' => 17, 'commit_id' => HEAD, 'state' => 'COMMENTED',
                                'body' => 'Tour' }.merge(changes)
      assert_blocked(/submitted COMMENT review/)
    end
  end
end

class MergeQueueSubmissionTest < Minitest::Test
  include MergeFixtures

  def test_enqueues_a_clean_queue_enabled_pull_request_at_the_expected_head
    entry = queue_entry(position: 1)
    ready = snapshot.merge('isMergeQueueEnabled' => true)
    queued = ready.merge('isInMergeQueue' => true, 'mergeQueueEntry' => entry)
    @client.snapshots = [ready, ready, queued]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => entry } }

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_queue_result(result, entry)
    query, variables = @client.mutations.fetch(0)
    assert_queue_mutation(query, variables)
  end

  def test_queue_enabled_pull_request_can_enqueue_when_the_base_advanced
    entry = queue_entry
    ready = snapshot.merge('isMergeQueueEnabled' => true, 'mergeStateStatus' => 'BEHIND')
    queued = ready.merge('isInMergeQueue' => true, 'mergeQueueEntry' => entry)
    @client.snapshots = [ready, ready, queued]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => entry } }

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_equal ['merge_queue', 1], [result.fetch('submission'), @client.mutations.length]
  end

  def test_queue_enabled_pull_request_lets_github_decide_blocked_state
    entry = queue_entry
    ready = snapshot.merge('isMergeQueueEnabled' => true, 'mergeStateStatus' => 'BLOCKED')
    queued = ready.merge('isInMergeQueue' => true, 'mergeQueueEntry' => entry)
    @client.snapshots = [ready, ready, queued]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => entry } }

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_equal 'merge_queue', result.fetch('submission')
    assert_equal 1, @client.mutations.length
  end

  def test_queue_enabled_pull_request_rejects_conflicting_or_unknown_state
    %w[DIRTY DRAFT HAS_HOOKS UNKNOWN].each do |state|
      @client.snapshots = [snapshot.merge('isMergeQueueEnabled' => true, 'mergeStateStatus' => state)]
      assert_blocked(/not CLEAN or BEHIND or BLOCKED/)
    end
  end

  def test_existing_exact_head_queue_entry_is_idempotent
    entry = queue_entry(position: 2)
    queued = snapshot.merge('isMergeQueueEnabled' => true, 'isInMergeQueue' => true,
                            'mergeQueueEntry' => entry, 'mergeStateStatus' => 'UNKNOWN')
    @client.snapshots = [queued]

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_equal 'merge_queue', result.fetch('submission')
    assert_equal entry, result.fetch('mergeQueueEntry')
    assert_empty @client.mutations
  end

  def test_queue_submission_requires_a_confirmed_entry
    @client.snapshots = [snapshot.merge('isMergeQueueEnabled' => true)]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => nil } }

    error = assert_raises(Shaka::Error) { @merge.call(head: HEAD, walkthrough: 17) }

    assert_match(/did not confirm enqueueing.*inspect live PR state/, error.message)
  end

  def test_enqueue_accepts_a_nullable_mutation_head_when_readback_proves_the_target
    returned = queue_entry.merge('headCommit' => nil)
    confirmed = queue_entry
    ready = snapshot.merge('isMergeQueueEnabled' => true)
    queued = ready.merge('isInMergeQueue' => true, 'mergeQueueEntry' => confirmed)
    @client.snapshots = [ready, ready, queued]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => returned } }

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_queue_result(result, confirmed)
  end

  def test_existing_queue_entry_for_another_head_is_not_replayed
    queued = snapshot.merge('isMergeQueueEnabled' => true, 'isInMergeQueue' => true,
                            'mergeQueueEntry' => queue_entry(head: 'c' * 40), 'mergeStateStatus' => 'UNKNOWN')
    @client.snapshots = [queued]

    error = assert_raises(Shaka::Error) { @merge.call(head: HEAD, walkthrough: 17) }

    assert_match(/without the expected head entry/, error.message)
    assert_empty @client.mutations
  end

  def test_changed_base_after_reading_checks_blocks_before_submission
    @client.snapshots = [snapshot, snapshot.merge('baseRefName' => 'release')]

    assert_blocked(/base changed/)
  end

  def test_queue_submission_rejects_post_enqueue_retargeting
    entry = queue_entry
    ready = snapshot.merge('isMergeQueueEnabled' => true)
    retargeted = ready.merge('baseRefName' => 'release', 'isInMergeQueue' => true, 'mergeQueueEntry' => entry)
    @client.snapshots = [ready, ready, retargeted]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => entry } }

    error = assert_raises(Shaka::Error) { @merge.call(head: HEAD, walkthrough: 17) }

    assert_match(/did not confirm queueing the expected head and base.*inspect live PR state/, error.message)
    assert_equal 1, @client.mutations.length
  end

  private

  def assert_queue_mutation(query, variables)
    assert_includes query, 'enqueuePullRequest'
    assert_includes query, 'expectedHeadOid: $head'
    assert_equal({ 'id' => 'PR_123', 'head' => HEAD }, variables)
    assert_equal ['merge_queue'], @client.features
  end
end

class MergeQueueReconciliationTest < Minitest::Test
  include MergeFixtures

  def test_replay_does_not_reenqueue_an_entry_removed_while_reading_gates
    entry = queue_entry
    queued = snapshot.merge('isMergeQueueEnabled' => true, 'isInMergeQueue' => true,
                            'mergeQueueEntry' => entry, 'mergeStateStatus' => 'UNKNOWN')
    removed = snapshot.merge('isMergeQueueEnabled' => true, 'mergeStateStatus' => 'BLOCKED')
    @client.snapshots = [queued, removed]

    error = assert_raises(Shaka::Error) { @merge.call(head: HEAD, walkthrough: 17) }

    assert_match(/left the merge queue.*meaningful change/, error.message)
    assert_empty @client.mutations
  end

  def test_replay_reconciles_a_merge_that_finishes_while_reading_gates
    entry = queue_entry
    queued = snapshot.merge('isMergeQueueEnabled' => true, 'isInMergeQueue' => true,
                            'mergeQueueEntry' => entry, 'mergeStateStatus' => 'UNKNOWN')
    merged = queued.merge('state' => 'MERGED', 'merged' => true, 'mergeCommit' => { 'oid' => 'e' * 40 },
                          'isInMergeQueue' => false, 'mergeQueueEntry' => nil)
    @client.snapshots = [queued, merged]

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_equal 'MERGED', result.fetch('state')
    assert_equal 'e' * 40, result.dig('mergeCommit', 'oid')
    assert_empty @client.mutations
  end

  def test_enqueue_that_merges_before_readback_returns_terminal_evidence
    entry = queue_entry
    ready = snapshot.merge('isMergeQueueEnabled' => true)
    merged = ready.merge('state' => 'MERGED', 'merged' => true, 'mergeCommit' => { 'oid' => 'e' * 40 })
    @client.snapshots = [ready, ready, merged]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => entry } }

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_queue_result(result, entry)
    assert_equal 'MERGED', result.fetch('state')
    assert_equal 'e' * 40, result.dig('mergeCommit', 'oid')
  end

  def test_enqueue_reconciles_a_replacement_entry_for_the_same_target
    returned = queue_entry
    replacement = queue_entry.merge('id' => 'MQE_456')
    ready = snapshot.merge('isMergeQueueEnabled' => true)
    queued = ready.merge('isInMergeQueue' => true, 'mergeQueueEntry' => replacement)
    @client.snapshots = [ready, ready, queued]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => returned } }

    result = @merge.call(head: HEAD, walkthrough: 17)

    assert_queue_result(result, replacement)
  end
end

class MergeSubmissionTest < Minitest::Test
  include MergeFixtures

  def test_rejects_invalid_head_before_submission
    [nil, '', 'main'].each do |head|
      error = assert_raises(Shaka::Error) { @merge.call(head: head, walkthrough: 17) }
      assert_match(/full commit SHA/, error.message)
    end
    assert_empty @client.mutations
  end

  def test_initial_stale_head_or_missing_identity_blocks
    @client.snapshots = [snapshot.merge('headRefOid' => 'c' * 40)]
    assert_blocked(/PR head changed/)
    @client.snapshots = [snapshot.except('id')]
    assert_blocked(/identity is missing/)
    @client.snapshots = [snapshot.except('baseRefName')]
    assert_blocked(/base is missing/)
  end

  def test_passes_expected_head_to_server_and_returns_native_merge_result
    @client.snapshots = [snapshot.merge('reviewDecision' => 'APPROVED')]
    result = @merge.call(head: HEAD, walkthrough: 17)
    assert_equal 'b' * 40, result.dig('mergeCommit', 'oid')
    assert_equal 17, @client.requested_review
    query, variables = @client.mutations.fetch(0)
    assert_includes query, 'expectedHeadOid: $head'
    assert_equal({ 'id' => 'PR_123', 'head' => HEAD }, variables)
    assert_equal 1, @client.mutations.length
  end

  def test_changed_head_after_reading_checks_blocks
    @client.snapshots = [snapshot, snapshot.merge('headRefOid' => 'c' * 40)]
    assert_blocked(/PR head changed/)
  end

  def test_changed_gate_after_reading_checks_blocks
    @client.snapshots = [snapshot, snapshot.merge('reviewDecision' => 'CHANGES_REQUESTED')]
    assert_blocked(/Required reviews/)
  end

  def test_head_change_at_server_is_rejected_without_retry
    @client.mutation_error = Shaka::Error.new('Head branch was modified')
    error = assert_raises(Shaka::Error) { @merge.call(head: HEAD, walkthrough: 17) }
    assert_match(/Head branch was modified.*inspect live PR state/, error.message)
    assert_equal 1, @client.mutations.length
  end

  def test_unknown_mutation_outcome_requires_inspection
    [nil, 'merged', { 'pullRequest' => { 'state' => 'MERGED' } }].each do |payload|
      @client.mutation_result = { 'mergePullRequest' => payload }
      error = assert_raises(Shaka::Error) { @merge.call(head: HEAD, walkthrough: 17) }
      assert_match(/did not confirm.*inspect live PR state/, error.message)
    end
    assert_equal 3, @client.mutations.length
  end

  def test_snapshot_failure_does_not_submit
    @client.snapshots = [Shaka::Error.new('Snapshot unavailable')]
    assert_blocked(/Snapshot unavailable/)
  end
end
