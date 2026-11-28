# frozen_string_literal: true

require 'json'
require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/risk_replay'
require_relative '../skills/shaka/lib/shaka/post_implementation/packet'

class EvaluationRiskReplayTest < Minitest::Test
  CASES = File.expand_path('../eval/risk-replay', __dir__)
  CLI = File.expand_path('../eval/bin/review-replay', __dir__)

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

  def test_repeats_replay_each_pair_and_alternate_which_arm_goes_first
    replay = Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex', repeat: 3)
    calls = []
    replay.define_singleton_method(:replay) { |_row, arm| calls << arm }

    replay.send(:replay_pair, 'k01', 0)

    assert_equal %i[baseline candidate candidate baseline baseline candidate], calls
  end

  def test_a_report_without_a_known_rating_is_incomplete
    replay = Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex')
    result = { 'status' => 'completed', 'head' => 'c' * 40, 'reviewer' => 'openai/codex' }

    refute replay.send(:completed?, result, { 'head' => 'c' * 40 })
    assert replay.send(:completed?, result.merge('risk' => { 'rating' => 'low' }), { 'head' => 'c' * 40 })
    refute replay.send(:completed?, result.merge('risk' => Shaka::PostImplementationReport::LEGACY_RISK),
                       { 'head' => 'c' * 40 })
  end

  def test_each_record_names_its_whole_comparison_and_repeat
    saved = saved_plans(Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex', effort: 'low', repeat: 2))

    assert_equal [0, 0, 1, 1], saved.map(&:last)
    plans = saved.map(&:first).uniq
    assert_equal 1, plans.size
    assert_equal({ reviewer: 'openai/codex', effort: 'low', repeats: 2, cases: %w[k01] },
                 plans.first.slice(:reviewer, :effort, :repeats, :cases))
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

  # The comparison and repeat each replayed call would save, without running a fixture or a model.
  def saved_plans(replay)
    replay.instance_variable_get(:@comparison)[:cases] = %w[k01]
    saved = []
    replay.define_singleton_method(:replay) { |*| saved << [@comparison.dup, @repeat] }
    replay.send(:replay_pair, 'k01', 0)
    saved
  end

  def assert_frozen_case(row)
    assert_match(/\A[0-9a-f]{40}\z/, row.fetch('head'))
    assert_match(/\A[0-9a-f]{40}\z/, row.fetch('base'))
    assert_includes Shaka::PostImplementationReport::RISK, row.fetch('published')
    packet = JSON.parse(File.read(File.join(CASES, row.fetch('packet')), encoding: 'UTF-8'))
    Shaka::PostImplementationPacket.build(packet)
  end
end
