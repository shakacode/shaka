# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/risk_replay'

class EvaluationRiskReplayInputsTest < Minitest::Test
  ARMS = { baseline: { criteria: 'a' * 40, model: 'a' }, candidate: { criteria: 'b' * 40, model: 'b' } }.freeze

  def test_arms_with_different_policies_stop_before_any_spend
    replay = Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex', **ARMS)
    replay.define_singleton_method(:start_budget) { raise 'spent' }
    policies = { 'a' * 40 => { 'max_risk' => 'low' }, 'b' * 40 => { 'max_risk' => 'medium' } }

    error = replace(:policy, ->(_source, ref) { policies.fetch(ref) }) do
      assert_raises(ArgumentError) { replay.run([]) }
    end

    assert_includes error.message, 'different risk areas or thresholds'
  end

  def test_a_disabled_checkpoint_settles_at_zero_spend
    replay = Shaka::Evaluation::RiskReplay.new(reviewer: 'openai/codex')

    usage = replay.send(:usage_for, { 'status' => 'opted_out', 'reason' => 'Selected checkpoint.enabled is false' })

    assert_equal({ 'cache_neutral_dollars' => 0, 'billed_dollars' => 0 }, usage)
  end

  def test_the_policy_read_ignores_replacement_refs_and_restores_the_environment
    ENV['GIT_NO_REPLACE_OBJECTS'] = nil
    inside = Shaka::Evaluation::RiskReplayInputs.isolated_git { ENV.fetch('GIT_NO_REPLACE_OBJECTS', nil) }

    assert_equal '1', inside
    assert_nil ENV.fetch('GIT_NO_REPLACE_OBJECTS', nil)
  end

  def test_tools_name_the_helper_revision_and_report_unknown_for_a_missing_cli
    Dir.mktmpdir do |root|
      helper = File.join(root, 'skills/shaka/scripts/shaka')
      tools = replace(:version, ->(_cli) { 'UNKNOWN' }) do
        Shaka::Evaluation::RiskReplayInputs.tools(helper, 'codex')
      end

      assert_equal({ 'helper' => 'UNKNOWN', 'cli' => 'UNKNOWN' }, tools)
    end
  end

  private

  # Swaps one RiskReplayInputs function for the block's duration.
  def replace(name, implementation)
    inputs = Shaka::Evaluation::RiskReplayInputs
    original = inputs.method(name)
    inputs.define_singleton_method(name, &implementation)
    yield
  ensure
    inputs.define_singleton_method(name, original)
  end
end
