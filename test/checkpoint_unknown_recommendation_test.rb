# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/checkpoint'

# Issue #1187: UNKNOWN is a placeholder, so a start word cannot carry it into the PR record.
class CheckpointUnknownRecommendationTest < Minitest::Test
  PLACEHOLDERS = %w[UNKNOWN unknown].freeze
  CONTENT = { 'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
              'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium',
              'immediate_start' => true, 'settings_available' => true }.freeze

  def test_an_unknown_recommendation_pauses_for_the_agent_to_make_one
    %w[recommended_model recommended_effort].product(PLACEHOLDERS).each do |field, placeholder|
      result = Shaka::Checkpoint.new(CONTENT.merge(field => placeholder)).result
      assert_equal 'recommendation_missing', result['reason'], "#{field}=#{placeholder}"
    end
  end

  def test_a_model_named_like_unknown_is_still_a_recommendation
    %w[UNKNOWN-2 unknowns].each do |model|
      content = CONTENT.merge('recommended_model' => model, 'active_model' => model)
      assert_equal 'proceed', Shaka::Checkpoint.new(content).result.fetch('status')
    end
  end
end
