# frozen_string_literal: true

require_relative 'merge_test'
require 'shaka/merge_approval_label'

# A merge-approved label from a write-access maintainer chooses Auto for the PR, later pushes included.
class MergeApprovalLabelTest < Minitest::Test
  include MergeFixtures

  EVENTS = 'repos/owner/repo/issues/42/events?per_page=100&page=1'
  PERMISSION = 'repos/owner/repo/collaborators/%s/permission'
  REPO_LABEL = 'repos/owner/repo/labels/merge-approved'

  # Answers the event list, collaborator permissions, and repository label reads the label check makes.
  module LabelApi
    attr_accessor :events, :permissions, :label_status, :create_status

    def api_calls = (@api_calls ||= [])

    def api_list(path)
      api_calls << ['GET', path]
      return [] unless path == EVENTS
      # A list of event lists answers successive reads in turn, the last one repeating.
      return events unless events.first.is_a?(Array)

      events.length > 1 ? events.shift : events.first
    end

    def api(path, method: 'GET', fields: {}, expected: Hash)
      api_calls << [method, path, fields]
      login = permissions.keys.find { |name| path == format(PERMISSION, name) }
      return { 'user' => { 'login' => login }, 'permission' => permissions.fetch(login) } if login

      status = path == REPO_LABEL ? label_status : (create_status if method == 'POST')
      raise Shaka::Error.new("HTTP #{status}", http_status: status) if status

      expected == Array ? [] : {}
    end
  end

  def setup
    super
    @client.extend(LabelApi)
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

  def test_a_maintainers_label_merges_under_auto_and_names_who_chose_it
    result = merge

    assert_equal 'MERGED', result.fetch('state')
    assert_equal({ 'label' => 'merge-approved', 'labeled_by' => 'maintainer', 'labeled_at' => '2026-11-27T20:00:00Z' },
                 result.fetch('merge_approval'))
  end

  def test_a_push_after_the_label_keeps_the_choice
    # The events list a commit after the label; nothing compares the label with the head.
    @client.events = [labeled('maintainer'), { 'event' => 'committed', 'created_at' => '2026-11-27T21:00:00Z' }]

    assert_equal 'maintainer', merge.fetch('merge_approval').fetch('labeled_by')
    refute(@client.api_calls.any? { |method, _| method == 'DELETE' })
  end

  def test_refuses_a_label_added_without_write_access
    @client.events = [labeled('maintainer'), labeled('helper', event: 'unlabeled'), labeled('helper')]

    assert_blocked(/merge-approved does not choose Auto: "helper" added it without write access \(read\)/)
  end

  def test_refuses_a_label_added_by_an_account_github_cannot_confirm
    @client.events = [labeled('stranger')]

    assert_blocked(/"stranger" added it without write access \(unavailable\)/)
  end

  def test_refuses_without_the_label_or_an_event_adding_it
    @client.snapshots = [snapshot]
    assert_blocked(/merge-approved does not choose Auto: the PR does not carry it. Hand the PR back under Ask/)

    @client.snapshots = [approved]
    @client.events = [labeled('maintainer', name: 'bug')]
    assert_blocked(/GitHub lists no event adding it/)
  end

  def test_a_label_removed_before_submission_stops_the_merge
    @client.snapshots = [approved, snapshot]

    assert_blocked(/the PR does not carry it/)
  end

  def test_a_label_re_added_without_write_access_before_submission_stops_the_merge
    @client.events = [[labeled('maintainer')], [labeled('maintainer'), labeled('helper')]]

    assert_blocked(/"helper" added it without write access/)
  end

  def test_an_event_list_too_long_to_read_refuses_and_hands_back
    @client.define_singleton_method(:api_list) { |_path| Array.new(100) { {} } }

    assert_blocked(/too many events to find who added it. Hand the PR back under Ask/)
  end

  def test_the_label_exempts_no_auto_gate
    @client.head_checks = [passing('Validate'), { 'name' => 'windows', 'state' => 'FAILURE', 'bucket' => 'fail' }]

    assert_blocked(/not passing: windows/)
  end

  def test_a_hold_label_still_wins
    @client.snapshots = [approved('hold')]

    assert_blocked(/hold label "hold"/)
  end

  def test_the_repository_label_is_created_with_its_meaning_once
    label = Shaka::MergeApprovalLabel.new(@client)
    assert_equal 'present', label.ensure_repository_label

    @client.label_status = 404
    assert_equal 'created', label.ensure_repository_label
    assert_includes @client.api_calls, ['POST', 'repos/owner/repo/labels',
                                        { name: 'merge-approved', color: '0E8A16',
                                          description: Shaka::MergeApprovalLabel::DESCRIPTION }]

    @client.label_status = 500
    assert_match(/\Afailed: HTTP 500/, label.ensure_repository_label)
  end

  def test_a_label_another_run_created_is_present_and_a_forbidden_create_names_who_creates_it
    label = Shaka::MergeApprovalLabel.new(@client)
    @client.label_status = 404
    { 422 => /\Apresent\z/, 403 => /\Anot_created: .*a maintainer creates merge-approved/ }.each do |status, outcome|
      @client.create_status = status

      assert_match outcome, label.ensure_repository_label
    end
  end

  private

  def passing(name) = { 'name' => name, 'state' => 'SUCCESS', 'bucket' => 'pass' }
  def merge = @merge.call(head: HEAD, base: BASE, walkthrough: 17)
end
