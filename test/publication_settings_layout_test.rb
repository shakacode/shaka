# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/settings'

class PublicationSettingsLayoutTest < Minitest::Test
  UNRECORDED = /UNKNOWN.*Before push: validation.*Review/

  def test_expanding_the_block_shows_its_status_before_any_setting_value
    status, values = Shaka::PublicationSettings.new(current: captured).detail.fetch('body').split('<details>', 2)
    assert_includes status, 'UNKNOWN: rerun missing evidence'
    refute_includes status, '| source |'
    assert_includes values, '| source | trusted/team |'
    assert values.end_with?('</details>'), 'the values disclosure must close inside the block'
  end

  def test_a_column_with_no_recorded_setting_is_named_above_the_table_instead_of_shown
    body = Shaka::PublicationSettings.new(current: captured).detail.fetch('body')
    assert_operator body.index(UNRECORDED), :<, body.index('| Setting | Current merge input (not evidence) |')
    assert_includes body, '| merge.preference | ask |'
    refute_includes body, '| UNKNOWN | UNKNOWN |'
  end

  def test_no_recorded_column_leaves_the_omission_sentence_without_a_table
    body = Shaka::PublicationSettings.new.detail.fetch('body')
    assert_match(/#{UNRECORDED.source}.*Current merge input/, body)
    refute_includes body, '| Setting |'
  end

  def test_settings_redacted_in_every_shown_column_share_one_line
    [recorded(captured), Shaka::PublicationSettings.new(current: captured)].each do |settings|
      body = settings.detail.fetch('body')
      refute_includes body, '| commands |'
      assert_match(/^.*REDACTED.*: commands, paths, .*local_changes$/, body)
    end
  end

  def test_settings_unknown_in_every_shown_column_share_one_line
    [recorded(captured), Shaka::PublicationSettings.new(current: captured)].each do |settings|
      body = settings.detail.fetch('body')
      refute_includes body, '| defaults_changed |'
      assert_match(/^UNKNOWN in every column: .*overrides\.command.*defaults_changed/, body)
    end
  end

  def test_a_setting_recorded_in_one_column_keeps_its_row
    validation = captured.merge('overrides.command' => 'validate')
    body = recorded(captured, validation:).detail.fetch('body')
    assert_includes body, '| overrides.command | validate | UNKNOWN | UNKNOWN |'
  end

  def test_a_redacted_setting_keeps_its_row_while_another_shown_column_is_unknown
    body = recorded(captured, validation: captured.except('commands')).detail.fetch('body')
    assert_includes body, '| commands | UNKNOWN | REDACTED | REDACTED |'
    refute_includes body, ': commands, paths'
  end

  def test_a_setting_redacted_for_an_invalid_value_keeps_its_row
    body = recorded(captured.merge('merge.preference' => 'bogus')).detail.fetch('body')
    assert_includes body, '| merge.preference | REDACTED | REDACTED | REDACTED |'
  end

  private

  def recorded(snapshot, validation: snapshot)
    checks = { 'validation' => validation, 'review' => snapshot }.transform_values do |settings|
      [{ 'original' => { 'public_settings' => settings } }]
    end
    Shaka::PublicationSettings.new(verdict: { 'checks' => checks }, current: snapshot)
  end

  def captured
    config = Object.new.tap do |settings|
      def settings.to_h = { 'merge' => { 'preference' => 'ask' } }
      def settings.config_path = nil
    end
    Shaka::Evidence::PublicSettings.capture(config:, kind: 'trusted/team', ref: 'a' * 40,
                                            task_overrides: {}, installation: {})
  end
end
