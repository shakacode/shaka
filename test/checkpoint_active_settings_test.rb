# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/checkpoint'

# Reverses issue #58's pause: when the host already runs the recommended settings,
# asking the user to reply ready changes nothing, so no start word is needed.
class CheckpointActiveSettingsTest < Minitest::Test
  def test_active_recommended_settings_proceed_without_a_start_word
    [content, content.merge('requested_model' => 'gpt-5.6-terra', 'requested_effort' => 'medium')].each do |input|
      assert_equal({ 'status' => 'proceed' }, Shaka::Checkpoint.new(input).result)
    end
  end

  def test_without_a_start_word_other_host_settings_pause
    [{ 'active_model' => nil }, { 'active_effort' => 'high' }, { 'settings_available' => false }].each do |change|
      assert_equal 'immediate_start_not_authorized',
                   Shaka::Checkpoint.new(content.merge(change)).result.fetch('reason')
    end
  end

  private

  def content
    { 'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
      'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium',
      'immediate_start' => false, 'settings_available' => true }
  end
end
