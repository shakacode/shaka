# frozen_string_literal: true

module Shaka
  # Cursor on-demand list prices; credits stay unpublished.
  module CursorCost
    RATES = { 'grok-4.6' => { 'standard' => %w[2 0.5 6], 'fast' => %w[4 1 12] } }.freeze

    private

    def cursor_price(model, billing, mode, tokens)
      return [nil, 'Cursor credit rates unpublished'] if mode == :credits

      rate = RATES.dig(model, billing)
      return [nil, 'Unsupported provider or configured model'] unless rate

      input, cached, _, output = tokens
      rates = rate.map { |value| Rational(value) }
      [(((input - cached) * rates[0]) + (cached * rates[1]) + (output * rates[2])) / 1_000_000, nil]
    end
  end

  # Report copy for configured-model cost scenarios.
  module CostCopy
    VERIFIED = '2026-09-16'

    private

    def markdown(rows, reasons)
      <<~MARKDOWN

        Cost estimates are PARTIAL configured-model scenarios for the selected native responses.
        Actual charge: UNKNOWN (routed model, billing mode, service tier, account terms, and external work unavailable).

        <details>
        <summary>Cost scenarios</summary>

        Standard Codex credit and Standard OpenAI API-equivalent rates, plus Cursor on-demand
        Grok 4.6 list prices, verified #{VERIFIED}; historical rates and account-specific terms
        may differ. Effort has no price multiplier. Cached input and reasoning output are
        subsets, not extra charges. OpenAI API cache writes are included in input and priced
        separately; Codex credit cache-write pricing is unavailable. Cursor cache writes have
        no published separate rate and stay in ordinary input. The OpenAI API scenario applies
        each request's 272K context threshold before summing; Cursor reports apply none.

        | Provider | Configured model | Effort | Codex credits estimate | API-equivalent USD estimate |
        | --- | --- | --- | ---: | ---: |
        #{rows}

        #{reasons.uniq.join('; ')}
        Sources: [Codex credit rates](https://learn.chatgpt.com/docs/pricing#token-rates),
        API prices for [Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra),
        [Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol), and
        [Astra](https://developers.openai.com/api/docs/models/gpt-6-astra),
        [prompt-cache accounting](https://developers.openai.com/api/docs/guides/prompt-caching),
        [Cursor Grok 4.6](https://cursor.com/docs/models/grok-4-6), and
        [Cursor model pricing](https://cursor.com/docs/models-and-pricing).

        </details>
      MARKDOWN
    end

    def show(amount, unit)
      return 'UNKNOWN' unless amount

      formatted = format('%.6f', amount)
      unit == '$' ? "#{unit}#{formatted}" : "#{formatted} #{unit}"
    end

    def safe(value)
      value.is_a?(String) && value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._:-]{0,79}\z/) ? value : 'UNKNOWN'
    end
  end

  # Prices configured-model scenarios from disjoint per-response token categories.
  class CostEstimate
    include CursorCost
    include CostCopy

    THRESHOLD = 272_000
    RATES = {
      'gpt-5.6-terra' => { credits: %w[50 5 300], api: %w[2 0.2 12] },
      'gpt-5.6-sol' => { credits: %w[100 10 500], api: %w[4 0.4 20] },
      'gpt-6-astra' => { credits: %w[250 25 1250], api: %w[10 1 50] }
    }.freeze

    def initialize(responses, inclusive_input: true)
      @responses = responses
      @inclusive_input = inclusive_input
    end

    def report
      reasons = []
      rows = @responses.group_by { |record| [record['configuration'], record['billing_mode']] }.map do |key, group|
        row(key, group, reasons)
      end.join("\n")
      rows = '| UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |' if rows.empty?
      markdown(rows, reasons)
    end

    private

    def row(key, group, reasons)
      configuration, billing = key
      credits, credit_reason = total(group, :credits)
      api, api_reason = total(group, :api)
      reasons.concat([credit_reason, api_reason].compact)
      provider, model, _, effort = configuration
      model = "#{model}-fast" if provider == 'cursor' && billing == 'fast' && model.is_a?(String)
      "| #{[safe(provider), safe(model), safe(effort), show(credits, 'credits'), show(api, '$')].join(' | ')} |"
    end

    def total(group, mode)
      amounts = group.map { |record| price(record, mode) }
      reason = amounts.map(&:last).compact.first
      [reason ? nil : amounts.sum { |amount, _| amount }, reason]
    end

    # Every published rate here bills input inclusive of its cached and written subsets.
    def price(record, mode)
      return [nil, 'Cache-exclusive input is unpriced'] unless @inclusive_input

      provider, model = record['configuration']
      return [nil, 'Unsupported provider or configured model'] unless %w[openai cursor].include?(provider)

      tokens, reason = categories(record['usage'])
      return [nil, reason] if reason

      if provider == 'openai'
        openai_price(model, mode, tokens)
      else
        cursor_price(model, record['billing_mode'], mode, tokens)
      end
    end

    def openai_price(model, mode, tokens)
      rate = RATES.dig(model, mode)
      return [nil, 'Unsupported provider or configured model'] unless rate
      return [nil, 'Credit cache-write rate UNKNOWN'] if mode == :credits && tokens[2].positive?

      [bill(tokens, rate, mode) / 1_000_000, nil]
    end

    def categories(usage)
      return [nil, 'Incomplete billable token categories'] unless usage.is_a?(Hash)

      tokens = %w[input_tokens cached_input_tokens cache_write_input_tokens output_tokens].map { |field| usage[field] }
      return [nil, 'Incomplete billable token categories'] unless valid_counters?(tokens)

      input, cached, writes, output = tokens
      reasoning = usage['reasoning_output_tokens']
      return [nil, 'Inconsistent token subsets'] if cached + writes > input || invalid_reasoning?(reasoning, output)

      [tokens, nil]
    end

    def bill(tokens, rate, mode)
      large = mode == :api && tokens[0] > THRESHOLD
      (input_bill(tokens, rate, mode) * (large ? 2 : 1)) +
        (tokens[3] * Rational(rate[2]) * (large ? Rational(3, 2) : 1))
    end

    def input_bill(tokens, rate, mode)
      input, cached, writes = tokens
      input_rate, cached_rate = rate.first(2).map { |value| Rational(value) }
      amount = ((input - cached - writes) * input_rate) + (cached * cached_rate)
      mode == :api ? amount + (writes * input_rate * Rational(5, 4)) : amount
    end

    def valid_counters?(tokens)
      tokens.all? { |value| value.is_a?(Integer) && value >= 0 }
    end

    def invalid_reasoning?(reasoning, output)
      reasoning.is_a?(Integer) && (reasoning.negative? || reasoning > output)
    end
  end
end
