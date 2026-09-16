# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/checkpoint'

class CheckpointTest < Minitest::Test
  # Regression: a branch that always pauses would add a redundant user turn even
  # when intake supplied matching settings and immediate execution authorization.
  def test_matching_explicit_settings_with_immediate_start_satisfy_the_checkpoint
    result = Shaka::Checkpoint.new(default_content).result

    assert_equal 'proceed', result.fetch('status')
  end

  def test_inactive_matching_settings_pause_with_a_switch_action
    result = Shaka::Checkpoint.new(default_content.merge('active_model' => 'gpt-5.6-sol')).result

    assert_pause result, 'settings_inactive'
  end

  def test_differing_settings_pause_for_user_resolution
    result = Shaka::Checkpoint.new(default_content.merge('recommended_model' => 'gpt-5.6-sol')).result

    assert_pause result, 'settings_conflict'
  end

  def test_unavailable_settings_pause_with_an_available_settings_action
    result = Shaka::Checkpoint.new(default_content.merge('settings_available' => false)).result

    assert_pause result, 'settings_unavailable'
  end

  # Characterization from issue #58: matching settings alone do not make an
  # ambiguous intake an immediate implementation request.
  def test_matching_settings_without_immediate_start_pause_for_ready
    result = Shaka::Checkpoint.new(default_content.merge('immediate_start' => false)).result

    assert_pause result, 'immediate_start_not_authorized'
  end

  def test_missing_requested_settings_pause_for_confirmation
    content = default_content.except('requested_model', 'requested_effort')
    result = Shaka::Checkpoint.new(content).result

    assert_pause result, 'settings_not_explicit'
  end

  def test_unreported_active_settings_pause_for_confirmation
    content = default_content.except('active_model', 'active_effort')
    result = Shaka::Checkpoint.new(content).result

    assert_pause result, 'settings_unverified'
  end

  private

  def default_content
    {
      'requested_model' => 'gpt-5.6-terra', 'requested_effort' => 'medium',
      'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
      'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium',
      'immediate_start' => true, 'settings_available' => true
    }
  end

  def assert_pause(result, reason)
    assert_equal 'pause', result.fetch('status')
    assert_equal reason, result.fetch('reason')
    refute_empty result.fetch('action')
  end
end
