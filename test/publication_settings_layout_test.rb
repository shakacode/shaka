# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/settings'

class PublicationSettingsLayoutTest < Minitest::Test
  def test_expanding_the_block_shows_its_status_before_any_setting_value
    status, values = Shaka::PublicationSettings.new.detail.fetch('body').split('<details>', 2)
    assert_includes status, 'UNKNOWN: rerun missing evidence'
    refute_includes status, '| source |'
    assert_includes values, '| source | UNKNOWN | UNKNOWN | UNKNOWN |'
    assert values.end_with?('</details>'), 'the values disclosure must close inside the block'
  end

  def test_never_published_settings_share_one_line_while_unknown_ones_keep_their_row
    body = Shaka::PublicationSettings.new(current: captured).detail.fetch('body')
    refute_includes body, '| commands |'
    assert_match(/^.*REDACTED.*: commands, paths, .*local_changes$/, body)
    assert_includes body, '| defaults_changed | UNKNOWN | UNKNOWN | UNKNOWN |'
  end

  def test_settings_no_snapshot_recorded_keep_their_unknown_rows
    body = Shaka::PublicationSettings.new.detail.fetch('body')
    assert_includes body, '| commands | UNKNOWN | UNKNOWN | UNKNOWN |'
    refute_includes body, 'REDACTED'
  end

  def test_a_setting_redacted_for_an_invalid_value_keeps_its_row
    body = Shaka::PublicationSettings.new(current: { 'merge.preference' => 'bogus' }).detail.fetch('body')
    assert_includes body, '| merge.preference | UNKNOWN | UNKNOWN | REDACTED |'
  end

  private

  def captured
    config = Object.new.tap do |settings|
      def settings.to_h = { 'merge' => { 'preference' => 'ask' } }
      def settings.config_path = nil
    end
    Shaka::Evidence::PublicSettings.capture(config:, kind: 'trusted/team', ref: 'a' * 40,
                                            task_overrides: {}, installation: {})
  end
end
