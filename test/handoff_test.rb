# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/handoff'
require 'shaka/publication'

class HandoffTest < Minitest::Test
  HEAD = 'a' * 40
  OLD = 'c' * 40
  LABELS = 'repos/owner/repo/issues/42/labels'
  REVIEWS = 'repos/owner/repo/pulls/42/reviews'
  WIP = { 'owner' => 'm5 · Claude Code · k7q2', 'task' => 'shaka #256 handoff', 'thread' => 'UNKNOWN',
          'last_observed_activity' => '2026-09-25 13:31 HST', 'revision' => "feature @ #{HEAD}",
          'workspace' => 'UNKNOWN', 'unfinished_work' => 'none', 'stopped_because' => 'paused',
          'merge_authority' => 'ask', 'state' => 'awaiting hosted checks', 'next_action' => 'rerun handoff' }.freeze

  # Answers the reads handoff makes, so each test states only the PR state it cares about.
  class FakeGitHub
    attr_reader :repository, :number

    def initialize(pull)
      @repository = 'owner/repo'
      @number = 42
      @pull = pull
    end

    def snapshot = { 'state' => @pull[:state], 'headRefOid' => @pull[:head], 'number' => 42 }
    def required_checks = @pull[:checks]
    def configured_required_checks = []

    def api(path, **)
      return { 'login' => 'shaka-agent' } if path == 'user'
      raise "unexpected read #{path}" unless path == 'repos/owner/repo/pulls/42'

      { 'body' => @pull[:body] }
    end

    def api_list(path)
      return @pull[:labels].map { |name| { 'name' => name } } if path.start_with?(LABELS)
      return @pull[:reviews] if path.start_with?(REVIEWS)

      raise "unexpected list #{path}"
    end
  end

  IDENTITY = { 'agent' => 'Claude Code', 'provider' => 'Anthropic', 'model' => 'claude-opus-5-5',
               'effort' => 'medium' }.freeze
  PROVENANCE = { 'task_source' => 'issue', 'initial_prompt' => 'EXCLUDED', 'workflow_version' => 'v1',
                 'requested_model' => 'UNKNOWN', 'requested_effort' => 'UNKNOWN',
                 'recommended_model' => 'UNKNOWN', 'recommended_effort' => 'UNKNOWN',
                 'active_model' => 'UNKNOWN', 'active_effort' => 'UNKNOWN' }.freeze
  TABLE = { 'columns' => %w[Check Result], 'rows' => [%w[validate pass]] }.freeze
  USAGE = { 'summary' => 'Usage', 'body' => "| Provider | Native total |\n| --- | ---: |\n| anthropic | 1 |" }.freeze

  def self.description(wip = WIP)
    Shaka::Publication.description(
      'identity' => IDENTITY, 'summary' => 'A summary.', 'table' => TABLE, 'deployment' => 'none',
      'provenance' => PROVENANCE, 'details' => [USAGE], 'wip' => wip
    )
  end

  def description(wip = WIP) = self.class.description(wip)

  def walkthrough(head, author: 'shaka-agent')
    body = Shaka::Publication.walkthrough('identity' => IDENTITY, 'summary' => 'What changed.', 'head' => head)
    { 'id' => 7, 'state' => 'COMMENTED', 'body' => body, 'submitted_at' => '2026-09-25T00:00:00Z',
      'user' => { 'login' => author } }
  end

  def check(bucket) = { 'name' => 'validate', 'state' => bucket.upcase, 'bucket' => bucket }

  def handoff(expected: HEAD, woken_by: nil, **pull)
    defaults = { state: 'OPEN', head: HEAD, labels: ['awaiting-resume'], body: description,
                 reviews: [walkthrough(HEAD)], checks: [check('pass')] }
    Shaka::Handoff.new(FakeGitHub.new(defaults.merge(pull))).call(head: expected, woken_by:)
  end

  def test_a_labeled_current_pr_owes_nothing
    result = handoff

    assert_empty result.fetch('owed')
    assert_equal 'status', result.keys.first
    assert_equal "PR #42 OPEN head #{HEAD[0, 7]} · awaiting-resume · required checks 1 pass · " \
                 "walkthrough #{HEAD[0, 7]} · WIP #{HEAD[0, 7]}", result['status']
  end

  def test_an_open_pr_without_an_attention_label_owes_one
    result = handoff(labels: ['bug'])

    assert_equal 'no awaiting label', result['status'][/no awaiting label/]
    assert(result['owed'].any? { |item| item.include?('attention') })
  end

  def test_a_session_something_will_wake_needs_no_label
    result = handoff(labels: [], woken_by: 'background watcher')

    assert_empty result['owed']
    assert_includes result['status'], 'woken by background watcher'
  end

  def test_a_copied_walkthrough_from_another_account_is_ignored
    result = handoff(reviews: [walkthrough(HEAD), walkthrough(OLD, author: 'outsider')])

    assert_empty result['owed']
  end

  def test_two_attention_labels_are_owed_as_one_decision
    result = handoff(labels: %w[awaiting-answer awaiting-resume])

    assert(result['owed'].any? { |item| item.include?('exactly one') })
  end

  def test_merge_approval_while_required_checks_are_pending_is_owed
    result = handoff(labels: ['awaiting-merge-approval'], checks: [check('pending')])

    assert(result['owed'].any? { |item| item.include?('awaiting-merge-approval') })
  end

  def test_a_moved_head_is_owed
    result = handoff(expected: OLD)

    assert(result['owed'].any? { |item| item.include?('head moved') })
  end

  def test_a_missing_or_stale_wip_note_is_owed
    assert(handoff(body: 'no note').fetch('owed').any? { |item| item.include?('WIP Details is missing') })

    stale = handoff(body: description(WIP.merge('revision' => "feature @ #{OLD}")))
    assert(stale['owed'].any? { |item| item.include?('WIP Details names') })
  end

  def test_a_walkthrough_for_an_older_head_is_owed_but_a_missing_one_is_only_noted
    assert(handoff(reviews: [walkthrough(OLD)]).fetch('owed').any? { |item| item.include?('walkthrough') })

    missing = handoff(reviews: [])
    assert_empty missing['owed']
    assert(missing['notes'].any? { |item| item.include?('No walkthrough') })
  end

  def test_the_latest_walkthrough_wins
    result = handoff(reviews: [walkthrough(OLD), walkthrough(HEAD)])

    assert_empty result['owed']
  end

  def test_a_closed_pr_owes_nothing_and_reads_no_labels
    result = handoff(state: 'MERGED', labels: nil, reviews: nil)

    assert_empty result['owed']
    assert_equal "PR #42 MERGED head #{HEAD[0, 7]}", result['status']
  end

  def test_owed_work_exits_with_its_own_status
    assert_equal 0, Shaka::Handoff.exit_status(handoff)
    assert_equal Shaka::Handoff::OWED_EXIT, Shaka::Handoff.exit_status(handoff(labels: []))
  end

  def test_the_head_is_optional_for_a_resumed_session
    result = handoff(expected: nil)

    assert_empty result['owed']
  end
end

class WipDetailsRevisionTest < Minitest::Test
  def test_the_revision_reads_back_from_a_rendered_description
    body = HandoffTest.description

    assert_equal "feature @ #{HandoffTest::HEAD}", Shaka::WipDetails.revision(body)
  end

  def test_a_body_without_the_note_has_no_revision
    assert_nil Shaka::WipDetails.revision('plain body')
  end
end
