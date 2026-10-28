# frozen_string_literal: true

require_relative 'settings_snapshot_helper'

class PublicationSettingsSummaryTest < Minitest::Test
  include SettingsSnapshotHelper

  COMMITTED = "Repository settings from commit `#{REVISION[0, 7]}`".freeze
  POINTER = Shaka::PublicationSettings::VERSION_POINTER

  def test_the_block_opens_on_its_status_then_the_current_settings
    status, _note, current = settings_block(current: snapshot).split("\n\n")
    assert_equal 'No matching check records supplied. Rerun missing validation or review to record them.', status
    assert_equal "Current settings: #{COMMITTED}; Shaka installation: version 0.1.0, installed revision " \
                 "(#{POINTER})", current
  end

  def test_committed_settings_get_one_row_per_operation_instead_of_a_table_of_settings
    body = settings_block(current: snapshot, validation: [snapshot(command: 'validate')],
                          review: [snapshot(reviewer: 'openai/codex')])
    assert_includes body, "| Validation | #{COMMITTED} | validate |"
    assert_includes body, "| Review | #{COMMITTED} | openai/codex |"
    refute_includes body, '<details>'
    refute_includes body, '| merge.preference |'
  end

  def test_each_reviewer_gets_its_own_row
    reviews = [snapshot(reviewer: 'openai/codex'), snapshot(reviewer: 'anthropic/claude', effort: 'medium')]
    body = settings_block(current: snapshot, validation: [snapshot(command: 'validate')], review: reviews)
    assert_includes body, "| Review | #{COMMITTED} | openai/codex |"
    assert_includes body, "| Review | #{COMMITTED} | anthropic/claude, medium effort |"
  end

  def test_results_that_recorded_the_same_settings_still_get_a_row_each
    reviews = [snapshot(reviewer: 'openai/codex')] * 2
    body = settings_block(current: snapshot, validation: [snapshot(command: 'validate')], review: reviews)
    assert_equal 2, body.scan("| Review | #{COMMITTED} | openai/codex |").size
  end

  def test_a_result_recorded_at_another_settings_revision_shows_that_revision
    earlier = snapshot(ref: 'b' * 40, command: 'validate')
    body = settings_block(current: snapshot, validation: [earlier], review: [snapshot(reviewer: 'openai/codex')])
    assert_includes body, '| Validation | Repository settings from commit `bbbbbbb` | validate |'
    assert_includes body, "Current settings: #{COMMITTED}"
  end

  def test_a_result_that_recorded_no_settings_reads_unknown
    body = settings_block(current: snapshot, validation: [nil], review: [snapshot(reviewer: 'openai/codex')])
    assert_includes body, '| Validation | UNKNOWN | UNKNOWN |'
  end

  def test_without_results_there_are_no_operation_rows
    body = settings_block(current: snapshot)
    refute_includes body, '| Step |'
    refute_includes body, '| Review |'
  end

  def test_unread_settings_stay_unknown
    assert_includes Shaka::PublicationSettings.new.detail.fetch('body'),
                    'Current settings: UNKNOWN; Shaka installation: version UNKNOWN, ' \
                    "installation source unavailable (#{POINTER})"
  end

  def test_team_runs_omit_private_trial_cautions
    body = settings_block(current: snapshot, validation: [snapshot(command: 'validate')])
    assert_includes body, '| Step | Settings source | Run details |'
    refute_includes body, 'Private trials'
    refute_includes body, 'backup'
  end

  def test_missing_installation_record_does_not_claim_shaka_is_absent
    current = snapshot.merge('installation.source' => 'uninstalled')
    assert_includes settings_block(current:), "Shaka installation: version 0.1.0, no installation record (#{POINTER})"
  end

  def test_redacted_source_labels_remain_publishable_without_exposing_invalid_values
    current = snapshot.merge('source' => 'private-secret', 'installation.source' => 'private-secret')
    body = settings_block(current:)
    assert_includes body, "Current settings: REDACTED at `#{REVISION[0, 7]}`; " \
                          "Shaka installation: version 0.1.0, REDACTED (#{POINTER})"
    refute_includes body, 'private-secret'
  end
end
