# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/checkpoint'

class CheckpointCurrentSettingsTest < Minitest::Test
  def test_go_accepts_current_settings_with_missing_or_different_host_observations
    [{}, { 'active_effort' => 'high' }, { 'active_model' => 'other-model' },
     { 'settings_available' => false }].each do |observations|
      assert_equal({ 'status' => 'proceed' }, checkpoint(observations))
    end
  end

  def test_blank_requested_settings_accept_current_settings
    assert_equal({ 'status' => 'proceed' }, checkpoint('requested_model' => '  ', 'requested_effort' => nil))
  end

  def test_current_settings_still_require_start_and_established_value
    [{}, { 'active_effort' => 'high' }, { 'settings_available' => false }].each do |observations|
      result = checkpoint(observations.merge('immediate_start' => false))
      assert_equal 'immediate_start_not_authorized', result.fetch('reason')
      assert_equal 'Reply ready to begin implementation.', result.fetch('action')
    end
    assert_equal 'value_not_established', checkpoint('value_established' => false).fetch('reason')
    assert_equal 'recommendation_missing', checkpoint('recommended_effort' => nil).fetch('reason')
  end

  def test_malformed_requested_settings_do_not_authorize_current_settings
    malformed = [false, 0, [], {}]
    %w[requested_model requested_effort].each do |field|
      malformed.each do |value|
        assert_equal 'settings_conflict', checkpoint(field => value).fetch('reason')
      end
    end
  end

  private

  def checkpoint(changes)
    content = { 'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                'immediate_start' => true, 'settings_available' => true }
    Shaka::Checkpoint.new(content.merge(changes)).result
  end
end
