# frozen_string_literal: true

module Shaka
  # Anthropic list prices, which bill uncached input, cache reads and cache writes separately.
  module AnthropicCost
    # Per million tokens: input, cache read, 5-minute cache write, 1-hour cache write, output.
    # Every model Anthropic still serves outside limited-availability programs; retired models
    # are omitted because no current session routes to one.
    RATES = {
      'claude-fable-5-1' => %w[10 0.25 12.5 20 50],
      'claude-fable-5' => %w[10 1 12.5 20 50],
      'claude-opus-5' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-8' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-7' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-6' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-5' => %w[5 0.5 6.25 10 25],
      'claude-sonnet-5' => %w[2 0.2 2.5 4 10],
      'claude-sonnet-4-6' => %w[3 0.3 3.75 6 15],
      'claude-sonnet-4-5' => %w[3 0.3 3.75 6 15],
      'claude-haiku-4-5' => %w[1 0.1 1.25 2 5]
    }.freeze
    # Web search bills $10 per 1,000 requests on top of tokens; web fetch adds no charge.
    # Readers report no searches as zero, so a count that is absent here was never established.
    SEARCH_RATE = Rational(1, 100)
    # Pinning inference to the US multiplies every token category. Global is the default, so a
    # record that does not name US routing is priced at standard rates rather than refused.
    US_GEO_RATE = Rational(11, 10)

    private

    # Claude Code records only the routed model; exports that name a configured model use that.
    def anthropic_rate(configuration)
      return unless configuration.is_a?(Array)

      _provider, model, routed = configuration
      RATES[[routed, model].find { |name| RATES.key?(name) }]
    end

    def anthropic_price(record, mode)
      return [nil, 'Codex credits do not price Anthropic'] if mode == :credits

      rate = anthropic_rate(record['configuration'])
      return [nil, 'Unsupported provider or configured model'] unless rate

      speed = record['billing_mode']
      return [nil, speed_reason(speed)] unless speed == 'standard'

      priced, reason = anthropic_categories(record['usage'])
      reason ? [nil, reason] : [anthropic_bill(priced, rate), nil]
    end

    # Fast mode bills at its own rates, and a source that records no speed establishes neither.
    def speed_reason(speed)
      speed == 'fast' ? 'Anthropic fast-mode rates are not published here' : 'Billing speed UNKNOWN'
    end

    def anthropic_bill(priced, rate)
      tokens, searches, geo = priced
      billed = tokens.zip(rate).sum { |count, price| count * Rational(price) } / 1_000_000
      (billed * (geo == 'us' ? US_GEO_RATE : 1)) + (searches * SEARCH_RATE)
    end

    def anthropic_categories(usage)
      return [nil, 'Incomplete billable token categories'] unless usage.is_a?(Hash)

      counters = %w[input_tokens cached_input_tokens cache_write_input_tokens output_tokens].map { |key| usage[key] }
      return [nil, 'Incomplete billable token categories'] unless valid_counters?(counters)

      input, cached, writes, output = counters
      split = write_split(usage, writes)
      searches = usage['web_search_requests']
      reason = anthropic_reason(usage, writes, split, [searches, output])
      reason ? [nil, reason] : [[[input, cached, *split, output], searches, usage['inference_geo']], nil]
    end

    def anthropic_reason(usage, writes, split, tools)
      searches, output = tools
      anthropic_subset_reason(writes, split, usage['reasoning_output_tokens'], output) ||
        ('Server tool usage UNKNOWN' unless valid_counters?([searches]))
    end

    # A zero write total already establishes both TTL categories, however few the transcript names.
    def write_split(usage, writes)
      split = %w[cache_write_5m_input_tokens cache_write_1h_input_tokens].map { |key| usage[key] }
      writes.zero? ? split.map { |count| count || 0 } : split
    end

    # The two cache-write rates differ, so only a split that accounts for the whole total is priced.
    def anthropic_subset_reason(writes, split, reasoning, output)
      return 'Cache-write TTL split UNKNOWN' if split.any?(&:nil?)
      return 'Inconsistent token subsets' unless valid_counters?(split) && split.sum == writes

      'Inconsistent token subsets' if invalid_reasoning?(reasoning, output)
    end
  end
end
