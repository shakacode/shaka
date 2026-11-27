# frozen_string_literal: true

require 'json'
require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/risk_replay'
require_relative '../eval/lib/shaka/evaluation/risk_replay_score'
require_relative '../skills/shaka/lib/shaka/post_implementation/packet'

class EvaluationRiskReplayTest < Minitest::Test
  CASES = File.expand_path('../eval/risk-replay', __dir__)
  CLI = File.expand_path('../eval/bin/review-replay', __dir__)
  AREAS = [{ 'ci_and_trust' => ['.github/workflows/**/*'] }, { 'agent_instructions' => ['**/AGENTS.md'] }].freeze
  ROW = { 'id' => 'k1', 'published' => 'low', 'reference' => 'medium' }.freeze

  def test_frozen_cases_pin_commits_and_carry_valid_checkpoint_packets
    rows = File.foreach(File.join(CASES, 'v1.jsonl')).map { |line| JSON.parse(line) }

    refute_empty rows
    rows.each { |row| assert_frozen_case(row) }
  end

  def test_replay_runs_the_checkpoint_with_the_frozen_packet_and_each_arm_model
    replay = Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex', effort: 'medium',
                                               baseline: { criteria: 'a' * 40, model: 'base-model' })
    row = { 'base' => 'b' * 40, 'head' => 'c' * 40, 'packet' => 'packets/k01.json' }

    arguments = replay.send(:review_arguments, row, :baseline, '/fixture', 'd' * 40)

    assert_equal %w[post-implementation run], arguments.first(2)
    expected = { '--content-file' => File.join(CASES, 'packets/k01.json'), '--ref' => 'd' * 40,
                 '--model' => 'base-model', '--effort' => 'medium' }
    assert_equal(expected, expected.keys.to_h { |name| [name, arguments[arguments.index(name) + 1]] })
  end

  def test_repeat_replays_each_case_pair_that_many_times
    replay = Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex', repeat: 3)
    calls = []
    replay.define_singleton_method(:replay) { |row, arm| calls << [row, arm] }

    replay.send(:replay_pair, 'k01', 0)

    assert_equal 6, calls.size
  end

  def test_a_report_without_a_known_rating_is_incomplete
    replay = Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex')
    result = { 'status' => 'completed', 'head' => 'c' * 40, 'reviewer' => 'openai/codex' }

    refute replay.send(:completed?, result, { 'head' => 'c' * 40 })
    assert replay.send(:completed?, result.merge('risk' => { 'rating' => 'low' }), { 'head' => 'c' * 40 })
  end

  def test_underrating_below_the_reference_counts_as_a_wrong_auto_merge
    arm = score([rated('low'), rated('low')], paths: ['lib/a.rb']).dig('candidate', 'cases', 'k1')

    assert arm.fetch('consistent')
    assert_equal({ 'under' => 2 }, arm.fetch('against_reference'))
    assert_equal({ 'merges' => 2, 'holds' => 0, 'wrong_merges' => 2, 'needless_holds' => 0 }, arm.dig('auto', 'low'))
    assert_equal 0, arm.dig('auto', 'medium', 'wrong_merges')
  end

  def test_a_high_risk_area_holds_whatever_the_rating_and_threshold
    arm = score([rated('low')], paths: ['.github/workflows/ci.yml']).dig('candidate', 'cases', 'k1')

    assert_equal 0, arm.dig('auto', 'low', 'merges')
    assert_equal 0, arm.dig('auto', 'medium', 'merges')
  end

  def test_overrating_holds_what_the_reference_would_merge
    arm = score([rated('high'), rated('medium')], paths: ['lib/a.rb'], reference: 'low').dig('candidate', 'cases', 'k1')

    refute arm.fetch('consistent')
    assert_equal({ 'over' => 2 }, arm.fetch('against_reference'))
    assert_equal 2, arm.dig('auto', 'low', 'needless_holds')
    assert_equal 1, arm.dig('auto', 'medium', 'needless_holds')
  end

  def test_missing_reference_failures_and_usage_stay_visible
    failed = { 'arm' => 'candidate', 'case' => 'k1', 'result' => { 'status' => 'incomplete' }, 'usage' => {} }
    arm = score([rated('low'), failed], paths: ['lib/a.rb'], reference: nil).fetch('candidate')

    assert_equal 1, arm.fetch('failed')
    assert_equal 'UNKNOWN', arm.fetch('dollars')
    assert_equal 'UNKNOWN', arm.dig('cases', 'k1', 'against_reference')
    assert_equal 'UNKNOWN', arm.dig('cases', 'k1', 'auto', 'low', 'wrong_merges')
    assert_equal 1, arm.dig('cases', 'k1', 'matches_published')
  end

  def test_repeat_is_refused_outside_a_checkpoint_risk_replay
    Dir.mktmpdir do |directory|
      _, error, status = Open3.capture3(RbConfig.ruby, CLI, '--helper', RbConfig.ruby, '--state', directory,
                                        '--reviewer', 'openai/codex', '--criteria', 'a' * 40, '--baseline-model', 'a',
                                        '--candidate-model', 'b', '--repeat', '2', '--preview')

      refute_predicate status, :success?
      assert_includes error, 'Use --repeat from 1 to 5 with --checkpoint-risk'
    end
  end

  private

  def score(records, paths:, reference: 'medium')
    Shaka::Evaluation::RiskReplayScore.score(records:, cases: { 'k1' => ROW.merge('reference' => reference) },
                                             paths: { 'k1' => paths }, areas: { 'candidate' => AREAS })
  end

  def rated(rating)
    { 'arm' => 'candidate', 'case' => 'k1', 'usage' => { 'cache_neutral_dollars' => 0.5 },
      'result' => { 'status' => 'completed', 'duration_ms' => 10, 'risk' => { 'rating' => rating } } }
  end

  def assert_frozen_case(row)
    assert_match(/\A[0-9a-f]{40}\z/, row.fetch('head'))
    assert_match(/\A[0-9a-f]{40}\z/, row.fetch('base'))
    assert_includes Shaka::PostImplementationReport::RISK, row.fetch('published')
    packet = JSON.parse(File.read(File.join(CASES, row.fetch('packet')), encoding: 'UTF-8'))
    Shaka::PostImplementationPacket.build(packet)
  end
end
