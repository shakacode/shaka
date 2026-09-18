# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/checkpoint'

class CheckpointTest < Minitest::Test
  # One input per settings pause reason, so the precedence sweep covers all six.
  SETTINGS_PROBLEMS = {
    'settings_unavailable' => { 'settings_available' => false },
    'settings_not_explicit' => { 'requested_model' => nil },
    'settings_conflict' => { 'recommended_model' => 'gpt-5.6-sol' },
    'settings_unverified' => { 'active_effort' => nil },
    'settings_inactive' => { 'active_model' => 'gpt-5.6-sol' },
    'immediate_start_not_authorized' => { 'immediate_start' => false }
  }.freeze

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

  # Issue #36 section 5 retires evidence engines that judge natural-language claims,
  # so the helper carries the agent's own verdict instead of scoring the value text.
  def test_unestablished_value_pauses_agent_proposed_work
    result = Shaka::Checkpoint.new(default_content.merge('value_established' => false)).result

    assert_pause result, 'value_not_established'
  end

  def test_established_value_proceeds
    result = Shaka::Checkpoint.new(default_content.merge('value_established' => true)).result

    assert_equal 'proceed', result.fetch('status')
  end

  # A user who named the task already established its value, so the field is absent
  # for ordinary work and its absence must not add a turn.
  def test_absent_value_field_proceeds
    refute_includes default_content.keys, 'value_established'

    assert_equal 'proceed', Shaka::Checkpoint.new(default_content).result.fetch('status')
  end

  # Asking an agent to pick a model for work that should not happen wastes the turn,
  # so the value verdict outranks every settings reason. One case per reason.
  def test_unestablished_value_outranks_every_settings_reason
    SETTINGS_PROBLEMS.each do |reason, settings_problem|
      content = default_content.merge(settings_problem)

      assert_pause Shaka::Checkpoint.new(content).result, reason
      assert_pause Shaka::Checkpoint.new(content.merge('value_established' => false)).result,
                   'value_not_established'
    end
  end

  # An agent writes this field by hand into a JSON file. A string 'false' or a JSON
  # null meant to withhold the verdict must not read as an established value.
  def test_non_boolean_value_established_is_refused
    [nil, 'false', 'true', 0, [], {}].each do |junk|
      content = default_content.merge('value_established' => junk)

      error = assert_raises(Shaka::Error) { Shaka::Checkpoint.new(content).result }
      assert_includes error.message, 'value_established'
    end
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
