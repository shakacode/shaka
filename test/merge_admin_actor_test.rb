# frozen_string_literal: true

require_relative 'merge_test'

class MergeAdminActorTest < Minitest::Test
  include MergeFixtures

  def test_opt_in_allows_normal_merge_and_records_actor_decision
    @merge = Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => true })
    @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true)]

    result = @merge.call(head: HEAD, base: BASE, walkthrough: 17)

    assert_equal 'MERGED', result['state']
    assert_equal({ 'allow_admin_actor' => true, 'viewerCanMergeAsAdmin' => true,
                   'decision' => 'allowed_by_trusted_opt_in' }, result['actor_capability'])
    query, variables = @client.mutations.fetch(0)
    assert_includes query, 'mergePullRequest'
    assert_equal({ 'id' => 'PR_123', 'head' => HEAD }, variables)
    refute_match(/admin|bypass/i, query)
  end

  def test_omitted_and_false_refuse_admin_capability
    [Shaka::Merge.new(@client),
     Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => false })].each do |merge|
      @merge = merge
      @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true)]
      assert_blocked(/Admin capability caused refusal.*merge.allow_admin_actor/)
    end
  end

  def test_opt_in_refuses_missing_unknown_and_malformed_capability
    @merge = Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => true })
    [nil, 'true', 1].each do |value|
      @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => value)]
      assert_blocked(/Admin actor capability is unknown/)
    end
    @client.snapshots = [snapshot.except('viewerCanMergeAsAdmin')]
    assert_blocked(/Admin actor capability is unknown/)
  end

  def test_capability_is_rechecked_before_submission
    ready = snapshot.merge('viewerCanMergeAsAdmin' => false)
    @client.snapshots = [ready, ready.merge('viewerCanMergeAsAdmin' => true)]
    assert_blocked(/Admin capability caused refusal/)
    @merge = Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => true })
    @client.snapshots = [ready, ready.merge('viewerCanMergeAsAdmin' => nil)]
    assert_blocked(/Admin actor capability is unknown/)
  end

  def test_non_admin_actor_records_the_conservative_default
    result = @merge.call(head: HEAD, base: BASE, walkthrough: 17)
    assert_equal({ 'allow_admin_actor' => false, 'viewerCanMergeAsAdmin' => false,
                   'decision' => 'non_admin_actor' }, result['actor_capability'])
  end

  def test_opt_in_preserves_queue_submission_and_terminal_verification
    @merge = Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => true })
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

  def test_opt_in_preserves_required_check_gates
    @merge = Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => true })
    @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true)]
    %w[FAILURE PENDING MISSING].each do |state|
      @client.checks = [{ 'name' => 'Validate', 'state' => state }]
      assert_blocked(/Required check/)
    end
  end

  def test_opt_in_preserves_identity_review_native_state_and_limits
    @merge = Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => true })
    [{ 'headRefOid' => 'c' * 40 }, { 'baseRefName' => 'other' },
     { 'reviewDecision' => 'REVIEW_REQUIRED' }, { 'mergeStateStatus' => 'BEHIND' },
     { 'changedFiles' => 100 }].each do |changes|
      @client.snapshots = [snapshot.merge('viewerCanMergeAsAdmin' => true).merge(changes)]
      assert_blocked(/head changed|validated base|Required reviews|GitHub merge state|merge limits/)
    end
  end

  def test_opt_in_preserves_review_and_walkthrough_gates
    @merge = Shaka::Merge.new(@client, merge_policy: { 'allow_admin_actor' => true })
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
