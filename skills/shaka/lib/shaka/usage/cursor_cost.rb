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
end
