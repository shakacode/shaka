# frozen_string_literal: true

require_relative 'merge_test'

class MergeAdminActorTest < Minitest::Test
  include MergeFixtures

  def test_admin_capability_does_not_require_configuration
    @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true)]

    result = @merge.call(head: HEAD, base: BASE, walkthrough: 17)

    assert_equal 'MERGED', result['state']
    query, variables = @client.mutations.fetch(0)
    assert_includes query, 'mergePullRequest'
    assert_equal({ 'id' => 'PR_123', 'head' => HEAD }, variables)
  end

  def test_admin_capability_is_not_required_to_submit
    @client.snapshots = [snapshot.except('viewerCanMergeAsAdmin')]

    assert_equal 'MERGED', @merge.call(head: HEAD, base: BASE, walkthrough: 17)['state']
    assert_equal 1, @client.mutations.size
  end

  def test_capability_change_does_not_replace_readiness_checks
    ready = snapshot.merge('viewerCanMergeAsAdmin' => false)
    @client.snapshots = [ready, ready.merge('viewerCanMergeAsAdmin' => true, 'reviewDecision' => 'REVIEW_REQUIRED')]

    assert_blocked(/Required reviews/)
  end

  def test_admin_actor_preserves_queue_submission_and_terminal_verification
    ready = snapshot.merge('viewerCanMergeAsAdmin' => true, 'isMergeQueueEnabled' => true)
    entry = queue_entry
    terminal = ready.merge('state' => 'MERGED', 'merged' => true, 'mergeCommit' => { 'oid' => 'b' * 40 })
    @client.snapshots = [ready, ready, terminal]
    @client.mutation_result = { 'enqueuePullRequest' => { 'mergeQueueEntry' => entry } }

    result = @merge.call(head: HEAD, base: BASE, walkthrough: 17)
    assert_queue_result(result, entry)
    assert_equal 'MERGED', result['state']
    assert_normal_enqueue
  end

  def test_admin_actor_preserves_required_check_gates
    @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true)]
    %w[FAILURE PENDING MISSING].each do |state|
      @client.checks = [{ 'name' => 'Validate', 'state' => state }]
      assert_blocked(/Required check/)
    end
  end

  def test_admin_actor_preserves_identity_review_native_state_and_limits
    { 'headRefOid' => ['c' * 40, /head changed/], 'baseRefName' => ['other', /validated base/],
      'reviewDecision' => ['REVIEW_REQUIRED', /Required reviews/],
      'mergeStateStatus' => ['BEHIND', /GitHub merge state/],
      'changedFiles' => [100, /merge limits/] }.each do |key, (value, message)|
      @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true, key => value)]
      assert_blocked(message)
    end
  end

  def test_admin_actor_preserves_review_and_walkthrough_gates
    @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true)]
    @client.comments = []
    assert_blocked(/No local-review attestation/)
    @client.comments = [attestation_comment]
    @client.review_result['commit_id'] = 'c' * 40
    assert_blocked(/Walkthrough/)
  end

  private

  def assert_normal_enqueue
    query, variables = @client.mutations.fetch(0)
    assert_equal({ 'id' => 'PR_123', 'head' => HEAD }, variables)
    assert_includes query, 'enqueuePullRequest'
    refute_match(/admin|bypass/i, query)
  end
end
