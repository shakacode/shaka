# frozen_string_literal: true

require_relative 'provenance_history_test'

# Issue #1187: later publications re-entered the recommendation, rewriting the plan-time choice.
class ProvenanceRecommendationTest < Minitest::Test
  include ProvenanceHistoryFixture

  RECOMMENDED = '| Recommended model / effort |'

  def test_a_later_recommendation_keeps_the_recorded_one
    publish(HEADS[0])
    changed = PUBLIC_PROVENANCE.merge('recommended_model' => 'claude-opus-5-5', 'recommended_effort' => 'UNKNOWN')
    kept = Shaka::ProvenanceRecommendation.resolve(pull_for(HEADS[1]), changed).kept
    rendered = publish(HEADS[1], 'recommended_model' => 'claude-opus-5-5', 'recommended_effort' => 'UNKNOWN')

    assert_includes rendered, "#{RECOMMENDED} gpt-5.6-terra / medium |"
    assert_empty history_rows(rendered)
    assert_equal 'gpt-5.6-terra / medium', kept
  end

  def test_only_a_recorded_unknown_takes_a_new_value
    publish(HEADS[0], 'recommended_model' => 'UNKNOWN', 'recommended_effort' => 'high')
    rendered = publish(HEADS[1], 'recommended_effort' => 'low')

    assert_includes rendered, "#{RECOMMENDED} gpt-5.6-terra / high |"
    assert_equal 2, history_rows(rendered).size
  end

  def test_an_unchanged_recommendation_reports_nothing_kept
    publish(HEADS[0])
    assert_nil Shaka::ProvenanceRecommendation.resolve(pull_for(HEADS[1]), PUBLIC_PROVENANCE).kept
  end

  def test_a_fork_keeps_no_recorded_recommendation
    publish(HEADS[0])
    rendered = publish(HEADS[1], fork: true, 'recommended_model' => 'claude-opus-5-5')

    assert_includes rendered, "#{RECOMMENDED} claude-opus-5-5 / medium |"
  end

  # The kept value replaces the supplied one, so invalid input must still be refused first.
  def test_invalid_recommended_input_is_still_refused
    publish(HEADS[0])
    [nil, 7, 'bad value'].each do |value|
      error = assert_raises(Shaka::Error) { publish(HEADS[1], 'recommended_model' => value) }
      assert_includes error.message, 'recommended_model is invalid'
    end
  end
end
