# frozen_string_literal: true

module Shaka
  # Cursor on-demand list prices; credits stay unpublished.
  module CursorCost
    RATES = {
      'grok-4.6' => { 'standard' => %w[2 0.5 6], 'fast' => %w[4 1 12] },
      'grok-4.7' => { 'standard' => %w[2 0.5 6], 'fast' => %w[4 1 12] }
    }.freeze
    # Grok 4.7 input above this length uses a multiple of the standard rates.
    THRESHOLD = { 'grok-4.7' => 256_000 }.freeze
    LONG_CONTEXT = { 'standard' => 2, 'fast' => 3 }.freeze

    private

    def cursor_price(model, billing, mode, tokens)
      return [nil, 'Cursor credit rates unpublished'] if mode == :credits

      rate = cursor_rates(model, billing, tokens[0])
      return [nil, 'Unsupported provider or configured model'] unless rate

      input, cached, _, output = tokens
      [(((input - cached) * rate[0]) + (cached * rate[1]) + (output * rate[2])) / 1_000_000, nil]
    end

    def cursor_rates(model, billing, input)
      listed = RATES.dig(model, billing)
      return unless listed

      limit = THRESHOLD[model]
      return listed.map { |value| Rational(value) } unless limit && input > limit

      @cursor_threshold = true
      RATES.dig(model, 'standard').map { |value| Rational(value) * LONG_CONTEXT.fetch(billing) }
    end
  end
end
