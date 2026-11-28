# frozen_string_literal: true

require 'json'
require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/risk_replay_score'

class EvaluationRiskReplayScoreTest < Minitest::Test
  SETTINGS = { 'high' => { 'ci_and_trust' => ['.github/workflows/**/*'] },
               'medium' => { 'agent_instructions' => ['**/AGENTS.md'] }, 'max_risk' => 'low' }.freeze
  SCORE = File.expand_path('../eval/bin/risk-replay-score', __dir__)
  ROW = { 'id' => 'k1', 'published' => 'low', 'reference' => 'medium' }.freeze

  def test_underrating_below_the_reference_counts_as_a_wrong_risk_gate_pass
    arm = score([rated('low'), rated('low')], paths: ['lib/a.rb']).dig('candidate', 'cases', 'k1')

    assert arm.fetch('consistent')
    assert_equal({ 'under' => 2 }, arm.fetch('against_reference'))
    assert_equal({ 'passes' => 2, 'holds' => 0, 'wrong_passes' => 2, 'needless_holds' => 0 },
                 arm.dig('risk_gate', 'low'))
    assert_equal 0, arm.dig('risk_gate', 'medium', 'wrong_passes')
  end

  def test_a_high_risk_area_holds_whatever_the_rating_and_threshold
    arm = score([rated('low')], paths: ['.github/workflows/ci.yml']).dig('candidate', 'cases', 'k1')

    assert_equal 0, arm.dig('risk_gate', 'low', 'passes')
    assert_equal 0, arm.dig('risk_gate', 'medium', 'passes')
  end

  def test_overrating_holds_what_the_reference_would_merge
    arm = score([rated('high'), rated('medium')], paths: ['lib/a.rb'], reference: 'low').dig('candidate', 'cases', 'k1')

    refute arm.fetch('consistent')
    assert_equal({ 'over' => 2 }, arm.fetch('against_reference'))
    assert_equal 2, arm.dig('risk_gate', 'low', 'needless_holds')
    assert_equal 1, arm.dig('risk_gate', 'medium', 'needless_holds')
  end

  def test_missing_reference_failures_and_usage_stay_visible
    arm = score([rated('low'), failed], paths: ['lib/a.rb'], reference: nil).fetch('candidate')
    entry = arm.dig('cases', 'k1')

    assert_equal [1, 'UNKNOWN', 'low'], arm.values_at('failed', 'dollars', 'configured_max_risk')
    assert_equal({ 'attempted' => 2, 'rated' => 1, 'consistent' => 'UNKNOWN', 'against_reference' => 'UNKNOWN' },
                 entry.slice('attempted', 'rated', 'consistent', 'against_reference'))
    assert_equal 'UNKNOWN', entry.dig('risk_gate', 'low', 'wrong_passes')
  end

  def test_a_case_whose_every_repeat_failed_still_appears
    entry = score([failed, failed], paths: ['lib/a.rb']).dig('candidate', 'cases', 'k1')

    assert_equal({ 'attempted' => 2, 'rated' => 0, 'ratings' => [] }, entry.slice('attempted', 'rated', 'ratings'))
  end

  def test_runs_a_stopped_replay_never_made_count_as_unattempted
    arm = score([rated('low')], paths: ['lib/a.rb'], plan: { 'cases' => %w[k1 k2], 'repeats' => 3 }).fetch('candidate')

    assert_equal 5, arm.fetch('unattempted')
    assert_equal([2, 3], arm.fetch('cases').values.map { |entry| entry.fetch('unattempted') })
  end

  def test_a_report_whose_rating_the_parser_filled_in_counts_as_failed
    filled = rated('low').merge('result' => { 'status' => 'completed',
                                              'risk' => Shaka::PostImplementationReport::LEGACY_RISK })
    arm = score([filled, rated('unknown')], paths: ['lib/a.rb']).fetch('candidate')

    assert_equal 1, arm.fetch('failed')
    assert_equal ['unknown'], arm.dig('cases', 'k1', 'ratings')
    assert_equal 1, arm.dig('cases', 'k1', 'risk_gate', 'low', 'holds')
  end

  def test_scoring_refuses_a_state_directory_holding_two_comparisons
    [[{ 'model' => 'b' }, {}], [{}, { 'effort' => 'high' }]].each do |selection, comparison|
      assert_includes score_directory([{}, {}], [selection, comparison]), 'mixes comparisons'
    end
  end

  private

  def score(records, paths:, reference: 'medium', plan: { 'cases' => %w[k1], 'repeats' => 2 })
    cases = plan.fetch('cases').to_h { |id| [id, ROW.merge('id' => id, 'reference' => reference)] }
    Shaka::Evaluation::RiskReplayScore.score(records:, cases:, paths: cases.transform_values { paths },
                                             settings: { 'candidate' => SETTINGS }, plan:)
  end

  # Two records whose selection and comparison differ by the given changes; returns the scorer's error.
  def score_directory(*changes)
    Dir.mktmpdir do |directory|
      changes.transpose.each_with_index do |(selection, comparison), index|
        File.write(File.join(directory, "#{index}.json"), JSON.generate(record(selection, comparison)))
      end
      _, error, status = Open3.capture3(RbConfig.ruby, SCORE, '--state', directory)
      refute_predicate status, :success?
      error
    end
  end

  def record(selection, comparison)
    rated('low').merge('selection' => { 'criteria' => 'a' * 40, 'model' => 'a' }.merge(selection),
                       'comparison' => { 'effort' => 'low' }.merge(comparison))
  end

  def failed = { 'arm' => 'candidate', 'case' => 'k1', 'result' => { 'status' => 'incomplete' }, 'usage' => {} }

  def rated(rating)
    { 'arm' => 'candidate', 'case' => 'k1', 'usage' => { 'cache_neutral_dollars' => 0.5 },
      'result' => { 'status' => 'completed', 'duration_ms' => 10, 'risk' => { 'rating' => rating } } }
  end
end
