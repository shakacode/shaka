# frozen_string_literal: true

require_relative 'merge_test'
require 'shaka/merge_approval_label'

# Answers the event list, collaborator permissions, and repository label reads the label check makes.
module MergeApprovalLabelApi
  attr_accessor :events, :permissions, :label_status, :create_status

  def api_calls = (@api_calls ||= [])

  def api_list(path)
    api_calls << ['GET', path]
    return [] unless path == MergeApprovalLabelTest::EVENTS
    # A list of event lists answers successive reads in turn, the last one repeating.
    return events unless events.first.is_a?(Array)

    events.length > 1 ? events.shift : events.first
  end

  def api(path, method: 'GET', fields: {}, expected: Hash)
    api_calls << [method, path, fields]
    permission = permission_response(path)
    return permission if permission

    status = path == MergeApprovalLabelTest::REPO_LABEL ? next_label_status : (create_status if method == 'POST')
    raise Shaka::Error.new("HTTP #{status}", http_status: status) if status

    expected == Array ? [] : {}
  end

  def permission_response(path)
    login = permissions.keys.find { |name| path == format(MergeApprovalLabelTest::PERMISSION, name) }
    return unless login

    permission_read if respond_to?(:permission_read)
    { 'user' => { 'login' => login }, 'permission' => permissions.fetch(login) }
  end

  # A list of statuses answers successive label reads in turn, the last one repeating.
  def next_label_status
    return label_status unless label_status.is_a?(Array)

    label_status.length > 1 ? label_status.shift : label_status.first
  end
end

# Setup and helpers the merge-approved label tests share.
module MergeApprovalLabelCases
  def setup
    super
    @client.extend(MergeApprovalLabelApi)
    @client.head_checks = [passing('Validate')]
    @client.permissions = { 'maintainer' => 'admin', 'helper' => 'read', 'writer' => 'write' }
    @client.events = [labeled('maintainer')]
    @client.snapshots = [approved]
    @merge.auto = true
    @merge.label_approval = Shaka::MergeApprovalLabel.new(@client)
  end

  def labeled(login, name: 'merge-approved', event: 'labeled')
    { 'event' => event, 'actor' => { 'login' => login }, 'label' => { 'name' => name },
      'created_at' => '2026-11-27T20:00:00Z' }
  end

  def approved(*names)
    names = ['merge-approved', *names]
    snapshot.merge('labels' => { 'totalCount' => names.length, 'nodes' => names.map { |name| { 'name' => name } } })
  end

  def passing(name) = { 'name' => name, 'state' => 'SUCCESS', 'bucket' => 'pass' }
  def merge = @merge.call(head: MergeFixtures::HEAD, base: MergeFixtures::BASE, walkthrough: 17)
end

# A merge-approved label from a write-access maintainer chooses Auto for the PR, later pushes included.
class MergeApprovalLabelTest < Minitest::Test
  include MergeFixtures
  include MergeApprovalLabelCases

  EVENTS = 'repos/owner/repo/issues/42/events?per_page=100&page=1'
  PERMISSION = 'repos/owner/repo/collaborators/%s/permission'
  NAME = 'merge-approved'
  REPO_LABEL = 'repos/owner/repo/labels/merge-approved'

  def test_a_maintainers_label_merges_under_auto_and_names_who_chose_it
    result = merge

    assert_equal 'MERGED', result.fetch('state')
    assert_equal({ 'label' => 'merge-approved', 'labeled_by' => 'maintainer', 'labeled_at' => '2026-11-27T20:00:00Z' },
                 result.fetch('merge_approval'))
  end

  def test_a_push_after_the_label_keeps_the_choice
    @client.events = [labeled('maintainer'), { 'event' => 'committed', 'created_at' => '2026-11-27T21:00:00Z' }]

    assert_equal 'maintainer', merge.fetch('merge_approval').fetch('labeled_by')
    refute(@client.api_calls.any? { |method, _| method == 'DELETE' })
  end

  # An account GitHub cannot confirm is refused like one without write access.
  def test_refuses_a_label_added_without_write_access
    @client.events = [labeled('maintainer'), labeled('helper', event: 'unlabeled'), labeled('helper')]

    assert_blocked(/merge-approved does not choose Auto: "helper" added it without write access \(read\)/)

    { labeled('stranger') => /"stranger" added it without write access \(unavailable\)/,
      labeled('maintainer').merge('actor' => 'maintainer') => /nil added it without write access \(unknown\)/ }
      .each do |event, error|
        @client.events = [event]
        assert_blocked(error)
      end
  end

  def test_refuses_without_the_label_or_an_event_adding_it
    @client.snapshots = [snapshot]
    assert_blocked(/merge-approved does not choose Auto: the PR does not carry it. Hand the PR back under Ask/)

    @client.snapshots = [approved]
    @client.events = [labeled('maintainer', name: 'bug')]
    assert_blocked(/GitHub lists no event adding it/)
  end

  def test_a_label_re_added_without_write_access_before_submission_stops_the_merge
    @client.events = [[labeled('maintainer')], [labeled('maintainer'), labeled('helper')]]

    assert_blocked(/"helper" added it without write access/)
  end

  def test_a_removal_the_snapshot_has_not_caught_up_with_refuses
    @client.events = [labeled('maintainer'), labeled('maintainer', event: 'unlabeled')]

    assert_blocked(/GitHub lists its removal after it was added/)
  end

  def test_the_result_names_who_added_the_label_the_last_read_accepted
    @client.events = [[labeled('maintainer')], [labeled('maintainer'), labeled('writer')]]

    assert_equal 'writer', merge.fetch('merge_approval').fetch('labeled_by')
  end

  def test_an_event_list_too_long_to_read_refuses_and_hands_back
    @client.define_singleton_method(:api_list) { |_path| Array.new(100) { {} } }

    assert_blocked(/too many events to find who added it. Hand the PR back under Ask/)

    @client.define_singleton_method(:api_list) { |_path| raise Shaka::Error, 'HTTP 403' }
    assert_blocked(/did not list who added it \(HTTP 403\). Hand the PR back under Ask/)
  end

  def test_the_label_exempts_no_auto_gate
    @client.head_checks = [passing('Validate'), { 'name' => 'windows', 'state' => 'FAILURE', 'bucket' => 'fail' }]

    assert_blocked(/not passing: windows/)
  end

  def test_a_hold_label_still_wins
    @client.snapshots = [approved('hold')]

    assert_blocked(/hold label "hold"/)
  end
end

# Labeling a PR awaiting-merge-approval also gives the repository merge-approved with its meaning.
class MergeApprovalRepositoryLabelTest < Minitest::Test
  include MergeFixtures

  def setup
    super
    @client.extend(MergeApprovalLabelApi)
    @client.permissions = {}
  end

  def test_the_repository_label_is_created_with_its_meaning_once
    label = Shaka::MergeApprovalLabel.new(@client)
    assert_equal 'present', label.ensure_repository_label

    @client.label_status = 404
    assert_equal 'created', label.ensure_repository_label
    assert_includes @client.api_calls, ['POST', 'repos/owner/repo/labels',
                                        { name: 'merge-approved', color: '0E8A16',
                                          description: Shaka::MergeApprovalLabel::DESCRIPTION }]
  end

  # GitHub answers 422 both when another run created the label and when it rejects the create.
  def test_a_refused_create_is_present_only_when_a_read_finds_the_label
    label = Shaka::MergeApprovalLabel.new(@client)
    @client.create_status = 422
    @client.label_status = [404, nil]
    assert_equal 'present', label.ensure_repository_label

    @client.label_status = [404, 404]
    assert_match(/\Afailed: HTTP 404/, label.ensure_repository_label)

    @client.create_status = 403
    @client.label_status = 404
    assert_match(/\Anot_created: .*a maintainer creates merge-approved/, label.ensure_repository_label)
  end
end

# The label reads around a merge queue and around the final permission lookup.
class MergeApprovalLabelTimingTest < Minitest::Test
  include MergeFixtures
  include MergeApprovalLabelCases

  # The second lookup is the last label read, before the PR is read afresh for every other gate.
  # A PR that a person queues between the reads still has to carry the label at the last one.
  def test_a_label_removed_before_submission_stops_the_merge_even_once_queued
    @client.snapshots = [approved, snapshot]
    assert_blocked(/the PR does not carry it/)

    @client.snapshots = [approved, approved, snapshot.merge('isInMergeQueue' => true, 'isMergeQueueEnabled' => true)]

    assert_blocked(/the PR does not carry it/)
  end

  def test_a_hold_or_retarget_while_the_labeler_is_looked_up_stops_the_merge
    { approved('hold') => /hold label "hold"/,
      approved.merge('baseRefName' => 'release') => /base/i }.each do |pull, error|
      client = @client
      reads = 0
      client.define_singleton_method(:permission_read) { client.snapshots = [pull] if (reads += 1) == 2 }
      @client.snapshots = [approved]

      assert_blocked(error)
    end
  end

  # The label passed when the PR was enqueued; removing it later leaves the entry queued, as the guide says.
  # An unreadable newer change cannot leave an older writer's approval standing, and the time is required.
  def test_label_events_github_returns_incomplete_refuse
    [MergeApprovalLabelTest::NAME, { 'name' => '' }].each do |label|
      @client.events = [labeled('maintainer'), { 'event' => 'labeled', 'label' => label }]
      assert_blocked(/Auto: GitHub listed a label change it did not name. Hand/)
    end

    @client.events = [labeled('maintainer').except('created_at')]
    assert_blocked(/GitHub did not say when it was added/)

    @client.snapshots = [approved.merge('labels' => { 'totalCount' => 2,
                                                      'nodes' => [{ 'name' => MergeApprovalLabelTest::NAME }] })]
    assert_blocked(/complete label list. Hand the PR back under Ask/)
  end

  def test_a_queued_pr_reconciles_after_the_label_is_removed
    queued = snapshot.merge('isMergeQueueEnabled' => true, 'isInMergeQueue' => true,
                            'mergeQueueEntry' => queue_entry, 'mergeStateStatus' => 'UNKNOWN')
    @client.snapshots = [queued, queued.merge('state' => 'MERGED', 'merged' => true, 'isInMergeQueue' => false,
                                              'mergeCommit' => { 'oid' => 'e' * 40 }, 'mergeQueueEntry' => nil)]

    assert_equal 'MERGED', merge.fetch('state')
    assert(@client.api_calls.none? { |_, path| path == MergeApprovalLabelTest::EVENTS })
  end
end
