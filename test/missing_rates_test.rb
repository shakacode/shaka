# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/usage/missing_rates'

class MissingRatesTest < Minitest::Test
  def record(model = 'gpt-99-sol')
    { 'configuration' => ['openai', model],
      'usage' => { 'input_tokens' => 100, 'cached_input_tokens' => 0,
                   'cache_write_input_tokens' => 0, 'output_tokens' => 10 } }
  end

  def gaps(records = [record], inclusive_input: true)
    Shaka::MissingRates.new(records, inclusive_input:, rate_card: Shaka::RateCard.installed).gaps
  end

  def test_missing_rates_are_classified_per_supported_scenario
    assert_equal [%w[openai gpt-99-sol api], %w[openai gpt-99-sol credits]], gaps
    assert_empty gaps([record('gpt-6.1-sol')])
  end

  def test_missing_counters_unknown_identity_and_unsupported_shapes_are_not_gaps
    bad = record
    bad['usage'].delete('cached_input_tokens')
    assert_empty gaps([bad])
    bad = record
    bad['usage']['cached_input_tokens'] = 101
    assert_empty gaps([bad])
  end

  def test_unknown_identity_native_cost_and_unsupported_shapes_are_not_gaps
    assert_empty gaps([record('UNKNOWN')])
    assert_empty gaps([record('/private/model')])
    assert_empty gaps(inclusive_input: false)
    bad = record
    bad['usage']['native_cost_usd'] = nil
    assert_empty gaps([bad])
  end
end

class MissingRateScenariosTest < Minitest::Test
  def usage
    { 'input_tokens' => 100, 'cached_input_tokens' => 0, 'cache_write_input_tokens' => 0,
      'output_tokens' => 10, 'web_search_requests' => 0 }
  end

  def anthropic
    { 'configuration' => %w[anthropic UNKNOWN claude-opus-99], 'billing_mode' => 'standard', 'usage' => usage }
  end

  def cursor
    { 'configuration' => %w[cursor grok-99], 'billing_mode' => 'fast', 'usage' => usage }
  end

  def gaps(record, inclusive: true)
    Shaka::MissingRates.new([record], inclusive_input: inclusive).gaps
  end

  def test_anthropic_requires_supported_billing_and_complete_counters
    assert_equal [%w[anthropic claude-opus-99 standard]], gaps(anthropic, inclusive: false)
    assert_empty gaps(anthropic.merge('billing_mode' => 'fast'), inclusive: false)
    assert_empty gaps(anthropic.merge('usage' => usage.merge('web_search_requests' => nil)), inclusive: false)
  end

  def test_existing_routed_anthropic_rate_is_not_a_configured_model_gap
    known = anthropic.merge('configuration' => %w[anthropic claude-opus-99 claude-opus-5])
    assert_empty gaps(known, inclusive: false)
  end

  def test_cursor_requires_supported_billing_and_valid_counters
    assert_equal [%w[cursor grok-99 fast]], gaps(cursor)
    assert_empty gaps(cursor.merge('billing_mode' => 'UNKNOWN'))
    assert_empty gaps(cursor.merge('usage' => usage.merge('reasoning_output_tokens' => 'bad')))
  end

  def test_unpublished_openai_cache_write_credits_are_not_missing_rates
    openai = { 'configuration' => %w[openai gpt-99-sol], 'usage' => usage.merge('cache_write_input_tokens' => 1) }
    assert_equal [%w[openai gpt-99-sol api]], gaps(openai)
    assert_empty gaps(openai.merge('configuration' => %w[openai gpt-99-audio]))
  end
end
