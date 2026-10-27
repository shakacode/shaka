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
    saved = capture_usage(remove: 'nested')
    assert_equal 'requested-model', saved.dig('usage', 'models', 0, 'configured_model')
    assert_equal saved.dig('fingerprint', 'configured_model'), saved.dig('usage', 'models', 0, 'configured_model')
    assert_equal 'observed-model', saved.dig('usage', 'models', 0, 'routed_model')
  end

  def test_multiple_transcripts_keep_unknown_per_response_configuration
    saved = capture_usage
    assert_equal 'UNKNOWN', saved.dig('usage', 'models', 0, 'configured_model')
  end

  def test_only_a_child_transcript_cannot_inherit_the_root_configuration
    saved = capture_usage(remove: 'first.jsonl')
    assert_equal 'UNKNOWN', saved.dig('usage', 'models', 0, 'configured_model')
  end

  def test_codex_unknown_effort_cannot_inherit_a_root_launch
    observed = native_usage(configured: 'child-configured')
    observed['models'].first.merge!('provider' => 'openai', 'routed_model' => 'UNKNOWN', 'effort' => 'UNKNOWN')
    lock = { 'agent' => { 'name' => 'codex', 'model_name' => 'openai/root-configured',
                          'kwargs' => { 'reasoning_effort' => 'medium' } } }
    bound = Shaka::Evaluation::HarborFingerprint.bind_usage(observed, lock: lock, host: 'codex')
    assert_equal observed, bound
  end

  def test_other_providers_cannot_inherit_the_launch_configuration
    observed = native_usage
    observed['models'].first['provider'] = 'openai'
    assert_equal observed, bind(observed)
  end

  def test_unknown_effort_uses_launch_configuration_without_changing_native_input
    observed = native_usage
    observed['models'].first['effort'] = 'UNKNOWN'
    assert_equal 'medium', bind(observed).dig('models', 0, 'effort')
    assert_equal 'UNKNOWN', observed.dig('models', 0, 'effort')
  end

  def test_multiple_models_keep_unknown_per_response_configuration
    observed = native_usage
    observed['models'] << observed['models'].first.merge('routed_model' => 'secondary-model')
    assert_equal observed, bind(observed)
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

  def capture_usage(remove: nil)
    setup_harbor(host: 'claude-code')
    capture_native_files('claude-code')
    omit_session(remove) if remove
    observed = native_usage
    @usage.define_singleton_method(:read) { |**| observed }
    assert_equal 'complete', harbor_run['status']
    saved_harbor_record
  end

  def omit_session(relative)
    path = File.join(@bin, 'harbor')
    File.open(path, 'a') { it.puts "FileUtils.rm_rf(File.join(trial, 'agent/sessions', #{relative.inspect}))" }
  end

  def bind(usage, lock: { 'agent' => { 'name' => 'claude-code', 'model_name' => 'anthropic/requested-model',
                                       'kwargs' => { 'reasoning_effort' => 'medium' } } })
    Shaka::Evaluation::HarborFingerprint.bind_usage(usage, lock: lock, host: 'claude-code')
  end
end
