# frozen_string_literal: true

require_relative 'handoff_helper'

# Handoff owes a usage snapshot for the head, so usage reaches the PR before a turn ends or the host changes.
class HandoffUsageTest < Minitest::Test
  include HandoffHarness

  def test_a_snapshot_naming_the_head_settles_usage
    result = handoff

    assert_empty result.fetch('owed')
    assert_includes result.fetch('status'), "usage #{HEAD[0, 7]}"
  end

  def test_a_head_without_a_snapshot_owes_the_publish_command
    result = handoff(usage: [HandoffFixtures.usage_snapshot(OLD)])

    owed = result.fetch('owed').join
    assert_includes owed, "usage publish owner/repo 42 --commit #{HEAD} --contribution CATEGORY --event handoff"
    assert_includes result.fetch('status'), 'no usage snapshot'
    assert_equal Shaka::Handoff::OWED_EXIT, Shaka::Handoff.exit_status(result)
  end

  # A marker from an account without write access is not evidence, so it cannot settle the head.
  def test_an_outside_snapshot_does_not_settle_usage
    result = handoff(usage: [HandoffFixtures.usage_snapshot(HEAD, author: 'outsider')])

    assert_includes result.fetch('status'), 'no usage snapshot'
  end

  def test_a_stated_gap_turns_the_missing_snapshot_into_a_note
    result = run_with_gap('Copilot has no usage reader.', usage: [])

    assert_empty result.fetch('owed')
    assert_includes result.fetch('notes').join, "No usage snapshot for #{HEAD}: Copilot has no usage reader."
  end

  def test_an_unreadable_journal_is_owed_with_the_comment_to_repair
    broken = HandoffFixtures.comment(901, "#{Shaka::UsageJournal::MARK}\nnot a record")
    result = handoff(usage: [broken])

    owed = result.fetch('owed').join
    assert_includes owed, 'Usage snapshots are unread'
    assert_includes owed, 'issuecomment-901'
  end

  # Dropping a real writer's snapshot silently would let a stale head pass, so a failed permission read is owed.
  def test_a_failed_permission_read_is_owed
    result = handoff(usage: [HandoffFixtures.usage_snapshot(HEAD, author: 'flaky')], unverifiable: ['flaky'])

    assert_includes result.fetch('owed').join, 'Usage snapshots are unread'
  end

  # `collect` refuses two measurements of one response, so a successor could not recover this usage.
  def test_a_conflicting_journal_is_owed_even_when_it_names_the_head
    snapshots = [HandoffFixtures.usage_snapshot(HEAD, id: 901, response: 'r1'),
                 HandoffFixtures.usage_snapshot(OLD, id: 902, response: 'r1', input: '9')]
    result = handoff(usage: snapshots)

    assert_includes result.fetch('owed').join, 'conflicting input for response r1'
  end

  # A gap excuses a host with no usage reader, never a journal comment someone has to repair.
  def test_a_gap_does_not_excuse_an_unreadable_journal
    broken = HandoffFixtures.comment(901, "#{Shaka::UsageJournal::MARK}\nnot a record")
    result = run_with_gap('Copilot has no usage reader.', usage: [broken])

    assert_includes result.fetch('owed').join, 'Usage snapshots are unread'
  end

  # A reader that found nothing publishes a placeholder; it names the head but saves no usage.
  def test_a_placeholder_without_responses_does_not_settle_usage
    placeholder = HandoffFixtures.usage_snapshot(HEAD, response: nil)
    result = handoff(usage: [placeholder])

    assert_includes result.fetch('status'), 'no usage snapshot'
  end

  def test_a_blank_gap_is_refused
    error = assert_raises(Shaka::Error) { run_with_gap(' ') }
    assert_equal '--usage-gap needs a reason.', error.message
  end

  # The PR author's own account publishes usage too; its marked snapshot is not a comment awaiting a reply.
  def test_the_authors_journal_comment_is_not_an_unanswered_comment
    result = handoff(author: 'person', writers: ['person'],
                     usage: [HandoffFixtures.usage_snapshot(HEAD, author: 'person')])

    assert_empty result.fetch('owed')
    refute_includes result.fetch('status'), 'unanswered'
  end

  def test_the_cli_refuses_a_usage_gap_outside_handoff
    _output, error, status = Open3.capture3(*SHAKA_COMMAND, 'pr', 'owner/repo', '42', '--usage-gap', 'none')

    refute_predicate status, :success?
    assert_includes error, '--usage-gap is only for handoff.'
  end

  private

  def run_with_gap(reason, **pull)
    defaults = { state: 'OPEN', head: HEAD, labels: ['awaiting-resume'], body: description,
                 reviews: [walkthrough(HEAD)], checks: [check('pass')], comments: [] }
    handoff = Shaka::Handoff.new(HandoffFakeGitHub.new(defaults.merge(pull)))
    handoff.usage_gap = reason
    handoff.call(head: HEAD)
  end
end
