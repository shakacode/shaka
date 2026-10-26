# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/harbor_trial'
require_relative 'support/evaluation_budget_fixture'
require_relative 'support/evaluation_harbor_fixture'
require_relative 'support/evaluation_fingerprint_fixture'

class EvaluationHarborUsageBindingTest < Minitest::Test
  include EvaluationBudgetFixture
  include EvaluationHarborFixture
  include EvaluationFingerprintFixture

  def native_usage(configured: 'UNKNOWN')
    { 'models' => [{ 'provider' => 'anthropic', 'configured_model' => configured,
                     'routed_model' => 'observed-model', 'effort' => 'medium', 'input_tokens' => 1,
                     'cached_input_tokens' => 0, 'cache_write_tokens' => 0, 'output_tokens' => 1,
                     'reasoning_tokens' => 0 }], 'cache_neutral_dollars' => 1, 'billed_dollars' => 0.5 }
  end

  def test_saved_usage_and_fingerprint_share_the_observed_launch_configuration
    setup_harbor(host: 'claude-code')
    capture_native_files('claude-code')
    observed = native_usage
    @usage.define_singleton_method(:read) { |**| observed }
    assert_equal 'complete', harbor_run['status']
    saved = saved_harbor_record
    assert_equal 'requested-model', saved.dig('usage', 'models', 0, 'configured_model')
    assert_equal saved.dig('fingerprint', 'configured_model'), saved.dig('usage', 'models', 0, 'configured_model')
    assert_equal 'observed-model', saved.dig('usage', 'models', 0, 'routed_model')
  end

  def test_launch_cannot_replace_a_known_native_configuration_or_routed_model
    observed = native_usage(configured: 'native-configured')
    bound = bind(observed)
    assert_equal observed, bound
  end

  def test_unknown_routed_identity_stays_unknown
    observed = native_usage
    observed['models'].first['routed_model'] = 'UNKNOWN'
    bound = bind(observed)
    assert_equal 'UNKNOWN', observed.dig('models', 0, 'configured_model')
    assert_equal 1, bound['cache_neutral_dollars']
    assert_equal 'requested-model', bound.dig('models', 0, 'configured_model')
    assert_equal 'UNKNOWN', bound.dig('models', 0, 'routed_model')
  end

  def test_missing_or_foreign_launch_cannot_fill_unknown_identity
    [nil, {}, { 'agent' => { 'name' => 'codex', 'model_name' => 'other' } }].each do |lock|
      assert_equal native_usage, bind(native_usage, lock: lock)
    end
  end

  private

  def bind(usage, lock: { 'agent' => { 'name' => 'claude-code', 'model_name' => 'anthropic/requested-model',
                                       'kwargs' => { 'reasoning_effort' => 'medium' } } })
    Shaka::Evaluation::HarborFingerprint.bind_usage(usage, lock: lock, host: 'claude-code')
  end
end
