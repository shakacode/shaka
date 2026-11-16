# frozen_string_literal: true

require_relative 'publication_test'

class PublicationUserImpactTest < Minitest::Test
  def test_impact_follows_why_without_changing_the_summary
    impact = 'Library callers can pass a timeout to the renderer.'
    with_impact = render(INTENT.merge('user_impact' => impact))

    assert_includes with_impact, "## Summary\n\nA summary.\n\n## Intent"
    assert_includes with_impact, "**Why:** #{INTENT['why']}\n\n**User impact:** #{impact}\n\n**Task:**"
    refute_includes render(INTENT), '**User impact:**'
  end

  def test_impact_rejects_multiple_lines
    error = assert_raises(Shaka::Error) { render(INTENT.merge('user_impact' => "First\nSecond")) }
    assert_includes error.message, 'intent user_impact'
  end

  private

  def render(intent)
    content = PublicationRegressionTest.new(name).description_content('intent' => intent)
    Shaka::Publication.description(content)
  end
end
