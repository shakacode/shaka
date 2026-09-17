# frozen_string_literal: true

require_relative 'usage_test'
require_relative '../skills/shaka/lib/shaka/cost_estimate'

class UsageCostTest < Minitest::Test
  include UsageFixture

  def test_estimates_configured_model_scenarios_without_double_counting_subsets
    setting = priced_context('current', 'gpt-5.6-terra', effort: 'medium')
    response = priced_usage('priced', 'current', 200_000, cached: 40_000, output: 20_000)
    response[:payload][:usage][:reasoning_output_tokens] = 4_000
    report = run_report([setting, response, response])
    assert_includes report, '| openai | gpt-5.6-terra | medium | 14.200000 credits | $0.568000 |'
    assert_includes report, '1 responses'
    assert_includes report, 'Actual charge: UNKNOWN'
    assert_includes report, 'configured-model scenarios'
  end

  def test_api_estimate_prices_cache_writes_separately_and_credit_estimate_stays_unknown
    setting = priced_context('current', 'gpt-5.6-terra')
    response = priced_usage('priced', 'current', 200_000, cached: 40_000, writes: 20_000, output: 20_000)
    report = run_report([setting, response])
    assert_includes report, '| openai | gpt-5.6-terra | high | UNKNOWN | $0.578000 |'
    assert_includes report, 'Credit cache-write rate UNKNOWN'
  end

  def test_model_switches_and_large_context_are_priced_per_response
    records = [priced_context('first', 'gpt-5.6-terra'),
               priced_usage('first', 'first', 100, output: 0),
               priced_context('second', 'gpt-6-astra'),
               priced_usage('second', 'second', 272_001, output: 1_000_000)]
    report = run_report(records, '--turn', 'first', '--turn', 'second')
    assert_includes report, '| openai | gpt-5.6-terra | high | 0.005000 credits | $0.000200 |'
    assert_includes report, '| openai | gpt-6-astra | high | 1318.000250 credits | $80.440020 |'
    assert_includes report, '272K context threshold'
  end

  def test_unsupported_model_and_partial_counters_never_become_zero_cost
    missing = priced_usage('missing', 'current', 100)
    missing[:payload][:usage].delete(:cached_input_tokens)
    report = run_report([context('current'), missing])
    assert_includes report, '| openai | gpt-test | high | UNKNOWN | UNKNOWN |'
    refute_includes report, '0.000000 credits'
    report = run_report([priced_context('current', 'gpt-5.6-terra'), missing])
    assert_includes report, '| openai | gpt-5.6-terra | high | UNKNOWN | UNKNOWN |'
    assert_includes report, 'Incomplete billable token categories'
  end

  def test_unreported_cache_writes_and_inconsistent_subsets_keep_estimates_unknown
    setting = priced_context('current', 'gpt-5.6-terra')
    unreported = usage('first', 'current', 100)
    report = run_report([setting, unreported])
    assert_includes report, '| openai | gpt-5.6-terra | high | UNKNOWN | UNKNOWN |'
    impossible = priced_usage('second', 'current', 100, cached: 90, writes: 20)
    report = run_report([setting, impossible])
    assert_includes report, 'Inconsistent token subsets'
    refute_includes report, '$0.000'
  end

  def test_anthropic_usage_has_no_unverified_price
    record = { 'configuration' => %w[anthropic UNKNOWN claude-test high],
               'usage' => { 'input_tokens' => 100, 'cached_input_tokens' => 40,
                            'cache_write_input_tokens' => 7, 'output_tokens' => 20 } }
    report = Shaka::CostEstimate.new([record]).report
    assert_includes report, '| anthropic | UNKNOWN | high | UNKNOWN | UNKNOWN |'
    assert_includes report, 'Unsupported provider or configured model'
  end

  def test_cursor_grok_keeps_unpriced_writes_in_ordinary_input
    report = Shaka::CostEstimate.new([cursor_record]).report
    assert_includes report, '| cursor | grok-4.6 | medium | UNKNOWN | $0.000260 |'
    assert_includes report, 'Actual charge: UNKNOWN'
    assert_includes report, 'Cursor on-demand'
    refute_includes report, '0.000000'
  end

  def test_cursor_grok_fast_and_missing_billing_mode
    report = Shaka::CostEstimate.new([cursor_record(billing: 'fast')]).report
    assert_includes report, '| cursor | grok-4.6-fast | medium | UNKNOWN | $0.000520 |'
    unknown = cursor_record(billing: nil)
    report = Shaka::CostEstimate.new([unknown]).report
    assert_includes report, '| cursor | grok-4.6 | medium | UNKNOWN | UNKNOWN |'
    assert_includes report, 'Unsupported provider or configured model'
  end

  def test_cursor_long_context_does_not_invent_a_threshold
    record = cursor_record(usage: { 'input_tokens' => 200_000, 'cached_input_tokens' => 0,
                                    'cache_write_input_tokens' => 0, 'output_tokens' => 0 })
    report = Shaka::CostEstimate.new([record]).report
    assert_includes report, '| cursor | grok-4.6 | medium | UNKNOWN | $0.400000 |'
    refute_includes report, '$0.800000'
  end

  private

  def priced_context(turn, model, effort: 'high')
    context(turn).tap { |setting| setting[:payload].merge!(model: model, effort: effort) }
  end

  def priced_usage(id, turn, input, **tokens)
    usage(id, turn, input).tap do |response|
      response[:payload][:usage].merge!(cached_input_tokens: tokens.fetch(:cached, 0),
                                        cache_write_input_tokens: tokens.fetch(:writes, 0),
                                        output_tokens: tokens.fetch(:output, 20), reasoning_output_tokens: 0)
    end
  end

  def cursor_record(billing: 'standard', usage: {})
    { 'configuration' => %w[cursor grok-4.6 cursor-grok-4.6-medium medium],
      'billing_mode' => billing,
      'usage' => { 'input_tokens' => 100, 'cached_input_tokens' => 40,
                   'cache_write_input_tokens' => 7, 'output_tokens' => 20 }.merge(usage) }
  end
end
