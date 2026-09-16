# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/recommendation'

class RecommendationTest < Minitest::Test
  CONTENT = {
    'scope' => 'One instruction and one behavior test.',
    'risk' => 'Changes agent selection policy.',
    'model' => 'gpt-example',
    'effort' => 'medium',
    'reason' => 'The policy change needs careful reasoning.'
  }.freeze

  def test_renders_assessment_before_the_result
    assert_equal <<~MARKDOWN, Shaka::Recommendation.new(CONTENT).render
      Scope: One instruction and one behavior test.
      Risk: Changes agent selection policy.
      Model: gpt-example
      Effort: medium
      Reason: The policy change needs careful reasoning.
    MARKDOWN
  end

  def test_requires_each_part_instead_of_supplying_a_default
    CONTENT.each_key do |field|
      error = assert_raises(Shaka::Error) { Shaka::Recommendation.new(CONTENT.reject { |key| key == field }).render }
      assert_includes error.message, field
    end
  end
end
