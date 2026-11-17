# frozen_string_literal: true

require_relative 'provenance_history_test'

# Issue #1187: the PR record keeps the plan-time recommendation until a stated replan.
class ProvenanceRecommendationTest < Minitest::Test
  include ProvenanceHistoryFixture

  REASON = 'The design grew past the first plan.'

  # Issue #1187: later publications re-entered the recommendation, rewriting the plan-time choice.
  def test_a_recommendation_changed_without_a_reason_keeps_the_recorded_one
    publish(HEADS[0])
    pull = pull_for(HEADS[1])
    changed = PUBLIC_PROVENANCE.merge('recommended_model' => 'claude-opus-5-5')
    rendered = publish(HEADS[1], 'recommended_model' => 'claude-opus-5-5')

    assert_includes rendered, '| Recommended model / effort | gpt-5.6-terra / medium |'
    assert_empty history_rows(rendered)
    assert_equal 'gpt-5.6-terra / medium', Shaka::ProvenanceRecommendation.resolve(pull, changed).kept
  end

  def test_a_stated_reason_records_the_new_recommendation_once
    publish(HEADS[0])
    replan = { 'recommended_model' => 'claude-opus-5-5', 'recommendation_change_reason' => REASON }
    publish(HEADS[1], **replan)
    rendered = publish(HEADS[2], **replan)

    assert_includes rendered, '| Recommended model / effort | claude-opus-5-5 / medium |'
    assert_includes rendered, '| Why the recommendation changed |'
    assert_rows([[HEADS[0], '| gpt-5.6-terra / medium | gpt-5.6-terra / medium |  |'],
                 [HEADS[1], "| claude-opus-5-5 / medium | gpt-5.6-terra / medium | #{REASON} |"]])
  end

  def test_a_recorded_unknown_yields_but_a_concrete_value_never_becomes_unknown
    publish(HEADS[0], 'recommended_model' => 'UNKNOWN')
    publish(HEADS[1])
    rendered = publish(HEADS[2], 'recommended_effort' => 'UNKNOWN',
                                 'recommendation_change_reason' => 'Lost the plan.')

    assert_includes rendered, '| Recommended model / effort | gpt-5.6-terra / medium |'
    assert_rows([[HEADS[0], '| UNKNOWN / medium |'], [HEADS[1], '| gpt-5.6-terra / medium | gpt-5.6-terra / medium |']])
  end

  # Review finding: replacing a recorded UNKNOWN model also dropped the recorded concrete effort.
  def test_each_setting_keeps_its_own_recorded_value
    publish(HEADS[0], 'recommended_model' => 'UNKNOWN', 'recommended_effort' => 'high')
    rendered = publish(HEADS[1], 'recommended_effort' => 'low')

    assert_includes rendered, '| Recommended model / effort | gpt-5.6-terra / high |'
    pull = pull_for(HEADS[2])
    kept = Shaka::ProvenanceRecommendation.resolve(pull, PUBLIC_PROVENANCE.merge('recommended_effort' => 'low')).kept
    assert_equal 'gpt-5.6-terra / high', kept
  end

  # Review finding: the recorded value used to replace invalid input before validation saw it.
  def test_invalid_recommended_input_is_still_refused
    publish(HEADS[0])
    [nil, 7, 'bad value'].each do |value|
      error = assert_raises(Shaka::Error) { publish(HEADS[1], 'recommended_model' => value) }
      assert_includes error.message, 'recommended_model is invalid'
    end
  end

  def test_an_unchanged_recommendation_reports_nothing_kept
    publish(HEADS[0])
    assert_nil Shaka::ProvenanceRecommendation.resolve(pull_for(HEADS[1]), PUBLIC_PROVENANCE).kept
  end

  def test_a_fork_keeps_no_recorded_recommendation
    publish(HEADS[0])
    rendered = publish(HEADS[1], fork: true, 'recommended_model' => 'claude-opus-5-5')

    assert_includes rendered, '| Recommended model / effort | claude-opus-5-5 / medium |'
  end

  def test_a_reason_that_could_break_the_table_or_marker_is_refused
    ["two\nlines", 'a | b', 'ends -->', 'x' * 201, ' padded', ''].each do |reason|
      error = assert_raises(Shaka::Error) { publish(HEADS[0], 'recommendation_change_reason' => reason) }
      assert_includes error.message, 'recommendation_change_reason'
    end
  end

  def test_a_tampered_reason_is_refused
    publish(HEADS[0])
    publish(HEADS[1], 'recommended_model' => 'claude-opus-5-5', 'recommendation_change_reason' => 'Replanned.')
    assert_refused(@body.sub('"reason":"Replanned."', '"reason":"a | b"'))
    assert_refused(@body.sub('"reason":"Replanned."', '"reason":7'))
  end

  private

  def assert_rows(expected)
    rows = history_rows(@body)
    assert_equal expected.size, rows.size
    rows.zip(expected).each do |row, (head, text)|
      assert row.start_with?("| `#{head[0, 7]}` |"), row
      assert_includes row, text
    end
  end

  def assert_refused(body)
    error = assert_raises(Shaka::Error) do
      Shaka::Publication.description(content, workflow, pull_for(HEADS[2], body))
    end
    assert_includes error.message, 'provenance history'
  end
end
