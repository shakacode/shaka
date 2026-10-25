# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/release_behavior_fixture'

class EvaluationReleaseBehaviorTest < Minitest::Test
  include ReleaseBehaviorFixture

  def test_complete_batch_passes_without_granting_publication_authority
    result = check
    assert_equal 'passed', result['status']
    assert_equal 12, result['cases']
    refute result['publication_authorized']
    assert_equal 'operator_attested', result.dig('limitations', 'execution')
    assert_includes result.dig('limitations', 'unknown_fingerprint_fields'), 'routed_model'
  end

  def test_requires_exactly_one_of_every_case_and_unique_trials
    @records.pop
    assert_equal 'incomplete_or_duplicate_cases', check['reason']
    @records << first
    assert_equal 'incomplete_or_duplicate_cases', check['reason']
  end

  def test_reused_trial_is_refused_even_with_complete_case_coverage
    @records.last['trial_id'] = first['trial_id']
    assert_equal 'incomplete_or_duplicate_cases', check['reason']
  end

  def test_malformed_and_empty_batches_are_refused
    [[], {}, nil, [{}]].each do |records|
      @records = records
      assert_equal 'invalid_records', check['reason']
    end
  end

  def test_records_must_match_the_actual_package_and_commit
    %w[skill_package_digest skill_commit workflow_hash enforcement_hash].each do |key|
      original = fingerprint[key]
      fingerprint[key] = key == 'skill_commit' ? '0' * 40 : "sha256:#{'0' * 64}"
      assert_equal 'unknown_or_modified_package', check['reason'], key
      fingerprint[key] = original
    end
  end

  def test_unknown_native_profile_is_refused
    %w[host_cli host_cli_version provider configured_model effort].each do |key|
      original = fingerprint[key]
      fingerprint[key] = 'UNKNOWN'
      assert_equal 'mixed_or_unknown_profile', check['reason'], key
      fingerprint[key] = original
    end
  end

  def test_mixed_profile_is_refused
    @records.last['fingerprint']['effort'] = 'high'
    assert_equal 'mixed_or_unknown_profile', check['reason']
  end

  def test_native_usage_mismatches_are_refused
    first['usage']['models'].first['configured_model'] = 'other-model'
    assert_equal 'mixed_or_unknown_profile', check['reason']
    first['usage']['models'] = []
    assert_equal 'mixed_or_unknown_profile', check['reason']
  end

  def test_bank_and_criteria_identity_cannot_be_substituted
    first['task']['kind'] = 'capability'
    assert_equal 'wrong_task_or_bank', failure_reason
    first['task']['kind'] = 'regression'
    fingerprint['criteria_set_hash'] = "sha256:#{'0' * 64}"
    assert_equal 'wrong_grading_criteria', failure_reason
  end

  def test_failed_or_missing_gates_and_harness_errors_cannot_pass
    original = JSON.generate(first)
    { 'gate' => [], 'score' => 99,
      'outcome' => { 'state' => 'HARNESS_ERROR', 'harness_error' => 'capture_failed' } }.each do |key, value|
      @records[0] = JSON.parse(original)
      first[key] = value
      assert_equal 'refused', check['status']
    end
  end

  def test_cost_must_be_accounted
    first['usage']['cache_neutral_dollars'] = 'UNKNOWN'
    assert_equal 'unaccounted_cost', failure_reason
  end

  def test_judges_are_advisory_and_cannot_rescue_failure
    first['judge'] = [{ 'model_id' => 'synthetic-judge', 'prompt_hash' => "sha256:#{'a' * 64}",
                        'kind' => 'rubric', 'dimension' => 'safety', 'verdict' => 'pass',
                        'confidence' => 1, 'critique' => 'Synthetic advisory judgment', 'facts' => {} }]
    assert_equal 'passed', check['status']
    first['gate'].first['passed'] = false
    assert_equal 'failed_or_missing_decision', failure_reason
  end
end
