# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/usage/cost_estimate'
require 'fileutils'
require 'yaml'

# Antigravity records Gemini usage with input that excludes cache reads and output that
# includes thinking, which Google's list prices bill as three separate charges.
class GoogleCostTest < Minitest::Test
  include MetricAssert

  def gemini(model, effort, timestamp: '2026-11-22T16:57:21Z', **usage)
    { 'configuration' => ['google', model, nil, effort], 'timestamp' => timestamp,
      'usage' => { 'input_tokens' => 1_000, 'cached_input_tokens' => 2_000, 'output_tokens' => 300 }.merge(usage) }
  end

  def estimate(*records, rate_card: nil)
    Shaka::CostEstimate.new(records, inclusive_input: false, rate_card: rate_card).report
  end

  def test_prices_input_cache_reads_and_output_separately
    report = estimate(gemini('gemini-4-neon-high', 'high'))
    # 1,000 input at $3, 2,000 cache reads at $0.15, and 300 output at $15 per million tokens.
    assert_metric report, 'USD estimate', '$0.007800'
    assert_includes report, 'Google Gemini API paid-tier list prices, verified'
    assert_includes report, '[Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)'
  end

  def test_a_dated_price_applies_from_its_utc_date
    before = estimate(gemini('gemini-4-argon-high', 'high', timestamp: '2026-11-30T23:59:59Z'))
    after = estimate(gemini('gemini-4-argon-high', 'high', timestamp: '2026-12-01T00:00:00Z'))
    offset = estimate(gemini('gemini-4-argon-high', 'high', timestamp: '2026-11-30T23:30:00-02:00'))
    assert_metric before, 'USD estimate', '$0.005200'
    assert_metric after, 'USD estimate', '$0.010400'
    assert_metric offset, 'USD estimate', '$0.010400'
  end

  def test_a_dated_price_needs_the_response_date
    [nil, 'yesterday'].each do |timestamp|
      report = estimate(gemini('gemini-4-argon-high', 'high', timestamp: timestamp))
      assert_metric report, 'USD estimate', 'UNKNOWN'
      assert_includes report, 'Response date UNKNOWN for the dated gemini-4-argon rate'
    end
  end

  def test_an_undated_price_needs_no_response_date
    assert_metric estimate(gemini('gemini-4-hydrogen-low', 'low', timestamp: nil)), 'USD estimate', '$0.003900'
  end

  def test_the_model_is_the_configured_id_or_that_id_without_its_effort
    assert_metric estimate(gemini('gemini-4-neon', nil)), 'USD estimate', '$0.007800'
    assert_metric estimate(gemini('gemini-3.8-flash-medium', 'medium')), 'USD estimate', '$0.002025'
    unpriced = estimate(gemini('gemini-pro-orchestrator-neon', nil))
    assert_metric unpriced, 'USD estimate', 'UNKNOWN'
    assert_includes unpriced, 'Unsupported provider or configured model'
    refute_includes unpriced, 'Google Gemini API'
  end

  def test_a_recorded_cache_write_or_missing_counter_leaves_the_response_unpriced
    assert_includes estimate(gemini('gemini-4-neon-high', 'high', 'cache_write_input_tokens' => 5)),
                    'Google cache writes unpriced'
    assert_includes estimate(gemini('gemini-4-neon-high', 'high', 'output_tokens' => nil)),
                    'Incomplete billable token categories'
  end

  def test_unpriced_responses_mark_the_column_partial
    report = estimate(gemini('gemini-4-neon-high', 'high'), gemini('gemini-4-neon-high', 'high', 'input_tokens' => -1))
    assert_metric report, 'USD estimate', '$0.007800 (partial)'
  end

  def test_inclusive_input_is_not_priced_on_google_rates
    report = Shaka::CostEstimate.new([gemini('gemini-4-neon-high', 'high')]).report
    assert_metric report, 'USD estimate', 'UNKNOWN'
  end
end

# A Shaka checkout cut before Google rates existed still has a card without them.
class GoogleRateCardTest < Minitest::Test
  def card(google)
    document = YAML.safe_load_file(Shaka::RateCard::INSTALLED_PATH)
    google ? document['google'] = google : document.delete('google')
    Dir.mktmpdir do |root|
      path = File.join(root, Shaka::RateCard::PATH)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(document))
      yield Shaka::RateCard.load_root(root)
    end
  end

  def model(entry) = { 'verified' => '2026-11-23', 'models' => { 'gemini-test' => entry } }

  def test_a_card_without_a_google_section_prices_no_google_model
    card(nil) do |rates|
      refute rates.google_model?('gemini-4-neon')
      assert_nil rates.google_name('gemini-4-neon-high', 'high')
    end
  end

  def test_price_changes_take_effect_in_date_order
    changes = { '2027-02-01' => %w[3 0.3 30], '2027-01-01' => %w[2 0.2 20] }
    card(model('prices' => %w[1 0.1 10], 'from' => changes)) do |rates|
      assert_equal %w[1 0.1 10], rates.google_prices('gemini-test', '2026-12-31')
      assert_equal %w[2 0.2 20], rates.google_prices('gemini-test', '2027-01-31')
      assert_equal %w[3 0.3 30], rates.google_prices('gemini-test', '2027-02-01')
    end
  end

  def test_a_malformed_google_entry_fails_the_card
    { { 'prices' => %w[1 0.1] } => 'gemini-test prices must be 3 prices',
      { 'prices' => %w[1 0.1 10], 'from' => { 'soon' => %w[2 0.2 20] } } => 'gemini-test from date must be YYYY-MM-DD',
      { 'prices' => %w[1 0.1 10], 'until' => '2027-01-01' } => 'unknown rate-card key: until' }.each do |entry, message|
      error = assert_raises(Shaka::Error) { card(model(entry)) { flunk 'card loaded' } }
      assert_includes error.message, message
    end
  end
end
