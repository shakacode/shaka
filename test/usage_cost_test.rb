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
    assert_metric report, 'Credits estimate', '14.200000'
    assert_metric report, 'USD estimate', '$0.568000'
    assert_includes report, '1 responses'
    assert_openai_sources report, 'gpt-5.6-terra'
    refute_unrelated_cost_copy report, 'gpt-5.6-sol', 'gpt-6-astra'
    refute_includes report, '272K'
  end

  def test_cost_headers_prefer_model_when_effort_also_differs
    records = [priced_context('first', 'gpt-5.6-terra', effort: 'high'),
               priced_usage('first', 'first', 100, output: 0),
               priced_context('second', 'gpt-6-astra', effort: 'low'),
               priced_usage('second', 'second', 100, output: 0)]
    report = run_report(records, '--turn', 'first', '--turn', 'second')
    cost = report.split('Cost scenarios', 2).last
    assert_metric cost, 'Metric', 'gpt-5.6-terra', 'gpt-6-astra'
    refute_includes cost, '| Metric | high | low |'
  end

  def test_api_estimate_prices_cache_writes_separately_and_credit_estimate_stays_unknown
    setting = priced_context('current', 'gpt-5.6-terra')
    response = priced_usage('priced', 'current', 200_000, cached: 40_000, writes: 20_000, output: 20_000)
    report = run_report([setting, response])
    assert_metric report, 'Credits estimate', 'UNKNOWN'
    assert_metric report, 'USD estimate', '$0.578000'
    assert_includes report, 'Credit cache-write rate UNKNOWN'
  end

  def test_model_switches_and_large_context_are_priced_per_response
    records = [priced_context('first', 'gpt-5.6-terra'),
               priced_usage('first', 'first', 100, output: 0),
               priced_context('second', 'gpt-6-astra'),
               priced_usage('second', 'second', 272_001, output: 1_000_000)]
    report = run_report(records, '--turn', 'first', '--turn', 'second')
    assert_metric report, 'Credits estimate', '0.005000', '1318.000250'
    assert_metric report, 'USD estimate', '$0.000200', '$80.440020'
    assert_includes report, '272K context threshold'
    assert_openai_sources report, 'gpt-5.6-terra', 'gpt-6-astra'
    refute_unrelated_cost_copy report, 'gpt-5.6-sol'
  end

  def test_unsupported_model_and_partial_counters_never_become_zero_cost
    missing = priced_usage('missing', 'current', 100)
    missing[:payload][:usage].delete(:cached_input_tokens)
    report = run_report([context('current'), missing])
    assert_metric report, 'USD estimate', 'UNKNOWN'
    refute_includes report, '0.000000'
    report = run_report([priced_context('current', 'gpt-5.6-terra'), missing])
    assert_metric report, 'Credits estimate', 'UNKNOWN'
    assert_metric report, 'USD estimate', 'UNKNOWN'
    assert_includes report, 'Incomplete billable token categories'
  end

  def test_unreported_cache_writes_and_inconsistent_subsets_keep_estimates_unknown
    setting = priced_context('current', 'gpt-5.6-terra')
    unreported = usage('first', 'current', 100)
    report = run_report([setting, unreported])
    assert_metric report, 'USD estimate', 'UNKNOWN'
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
    assert_metric report, 'USD estimate', 'UNKNOWN'
    refute_includes report, 'Credits estimate'
    refute_includes report, 'developers.openai.com'
    refute_includes report, 'cursor.com'
    refute_includes report, '2026-09-16'
    assert_includes report, 'Unsupported provider or configured model'
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

  def assert_openai_sources(report, *models)
    models.each { |model| assert_includes report, "models/#{model}" }
    assert_includes report, 'learn.chatgpt.com/docs/pricing'
  end

  def refute_unrelated_cost_copy(report, *models)
    models.each { |model| refute_includes report, model }
    refute_includes report, 'cursor.com'
    refute_includes report, 'Pi recorded'
  end
end

class UsageCursorCostTest < Minitest::Test
  def test_cursor_grok_keeps_unpriced_writes_in_ordinary_input
    report = Shaka::CostEstimate.new([cursor_record]).report
    assert_metric report, 'Metric', 'grok-4.6'
    assert_metric report, 'USD estimate', '$0.000260'
    refute_openai_cost_copy report
    refute_includes report, 'Cursor credit rates unpublished'
    assert_includes report, 'Cursor on-demand'
    assert_includes report, 'cursor.com/docs/models/grok-4-6'
  end

  def test_cursor_grok_fast_and_missing_billing_mode
    report = Shaka::CostEstimate.new([cursor_record(billing: 'fast')]).report
    assert_metric report, 'USD estimate', '$0.000520'
    report = Shaka::CostEstimate.new([cursor_record(billing: nil)]).report
    assert_metric report, 'USD estimate', 'UNKNOWN'
    assert_includes report, 'Unsupported provider or configured model'
  end

  def test_cursor_long_context_does_not_invent_a_threshold
    record = cursor_record(usage: { 'input_tokens' => 200_000, 'cached_input_tokens' => 0,
                                    'cache_write_input_tokens' => 0, 'output_tokens' => 0 })
    report = Shaka::CostEstimate.new([record]).report
    assert_metric report, 'USD estimate', '$0.400000'
    refute_includes report, '$0.800000'
    refute_includes report, '272K'
  end

  private

  def cursor_record(billing: 'standard', usage: {})
    { 'configuration' => %w[cursor grok-4.6 cursor-grok-4.6-medium medium],
      'billing_mode' => billing,
      'usage' => { 'input_tokens' => 100, 'cached_input_tokens' => 40,
                   'cache_write_input_tokens' => 7, 'output_tokens' => 20 }.merge(usage) }
  end

  def refute_openai_cost_copy(report)
    refute_includes report, 'Credits estimate'
    ['developers.openai.com', 'learn.chatgpt.com', 'Pi recorded', '0.000000'].each do |snippet|
      refute_includes report, snippet
    end
  end
end

class UsageNativePiCostTest < Minitest::Test
  def test_openai_provider_native_cost_does_not_use_rate_cards
    report = Shaka::CostEstimate.new([native_openai_record]).report
    assert_no_rate_card_copy report
    assert_metric report, 'USD estimate', '$0.000300'
    assert_includes report, 'Pi recorded native nominal USD'
  end

  def test_unavailable_native_cost_keeps_pi_provenance_not_rate_cards
    report = Shaka::CostEstimate.new([native_openai_record(cost: nil)]).report
    assert_no_rate_card_copy report
    assert_metric report, 'USD estimate', 'UNKNOWN'
    refute_includes report, 'Pi recorded native nominal USD'
  end

  def test_unsupported_openai_model_omits_rate_card_copy
    report = Shaka::CostEstimate.new([native_openai_record(cost: :omit, model: 'gpt-new')]).report
    assert_no_rate_card_copy report
    assert_metric report, 'USD estimate', 'UNKNOWN'
  end

  private

  def native_openai_record(cost: 0.0003, model: 'gpt-5.6-terra')
    usage = { 'input_tokens' => 100, 'cached_input_tokens' => 0,
              'cache_write_input_tokens' => 0, 'output_tokens' => 20 }
    usage['native_cost_usd'] = cost unless cost == :omit
    { 'configuration' => ['openai', model, 'UNKNOWN', 'high'], 'usage' => usage }
  end

  def assert_no_rate_card_copy(report)
    refute_includes report, 'Credits estimate'
    refute_includes report, '2026-09-16'
    refute_includes report, 'learn.chatgpt.com'
    refute_includes report, 'developers.openai.com'
  end
end
