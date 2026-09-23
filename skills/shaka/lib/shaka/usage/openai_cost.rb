# frozen_string_literal: true

module Shaka
  # OpenAI API-equivalent and Codex credit rates, including the 272K API context threshold.
  module OpenAICost
    THRESHOLD = 272_000
    RATES = {
      'gpt-5.6-terra' => { credits: %w[50 5 300], api: %w[2 0.2 12] },
      'gpt-5.6-sol' => { credits: %w[100 10 500], api: %w[4 0.4 20] },
      'gpt-6-astra' => { credits: %w[250 25 1250], api: %w[10 1 50] },
      'gpt-6-sol' => { credits: %w[50 5 250], api: %w[2 0.2 10] },
      'gpt-6-luna' => { credits: %w[2.5 0.25 12.5], api: %w[0.1 0.01 0.5] }
    }.freeze

    private

    def openai_price(model, mode, tokens)
      rate = RATES.dig(model, mode)
      return [nil, 'Unsupported provider or configured model'] unless rate
      return [nil, 'Credit cache-write rate UNKNOWN'] if mode == :credits && tokens[2].positive?

      [bill(tokens, rate, mode) / 1_000_000, nil]
    end

    def bill(tokens, rate, mode)
      large = mode == :api && tokens[0] > THRESHOLD
      @threshold = true if large
      (input_bill(tokens, rate, mode) * (large ? 2 : 1)) +
        (tokens[3] * Rational(rate[2]) * (large ? Rational(3, 2) : 1))
    end

    def input_bill(tokens, rate, mode)
      input, cached, writes = tokens
      input_rate, cached_rate = rate.first(2).map { |value| Rational(value) }
      amount = ((input - cached - writes) * input_rate) + (cached * cached_rate)
      mode == :api ? amount + (writes * input_rate * Rational(5, 4)) : amount
    end
  end
end
