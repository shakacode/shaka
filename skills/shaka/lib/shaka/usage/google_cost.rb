# frozen_string_literal: true

require 'date'
require 'time'
require_relative 'options'

module Shaka
  # Google Gemini API list prices, which bill uncached input, cache reads, and output separately.
  # Output includes thinking. Implicit caching has no write charge, so a recorded write is unpriced.
  module GoogleCost
    private

    def google_price(record, mode)
      return [nil, 'Codex credits do not price Google'] if mode == :credits

      _provider, configured, _routed, effort = record['configuration']
      model = @rate_card.google_name(configured, effort)
      return [nil, 'Unsupported provider or configured model'] unless model

      rate = @rate_card.google_prices(model, response_day(record['timestamp']))
      return [nil, "Response date UNKNOWN for the dated #{model} rate"] unless rate

      tokens, reason = google_categories(record['usage'])
      reason ? [nil, reason] : [tokens.zip(rate).sum { |count, price| count * Rational(price) } / 1_000_000, nil]
    end

    def google_intro(columns)
      return unless google_priced?(priced_columns(columns))

      "Google Gemini API paid-tier list prices, verified #{@rate_card.google_verified}. Uncached input, cache " \
        'reads and output are separate charges, and output includes thinking. A dated price applies from that ' \
        'UTC date of the response.'
    end

    def google_rated?(column)
      column[:provider] == 'google' && @google_counters && !@inclusive_input &&
        @rate_card.google_name(column[:model], column[:effort])
    end

    def google_categories(usage)
      return [nil, 'Incomplete billable token categories'] unless usage.is_a?(Hash)

      tokens = %w[input_tokens cached_input_tokens output_tokens].map { |key| usage[key] }
      return [nil, 'Incomplete billable token categories'] unless valid_counters?(tokens)
      return [nil, 'Google cache writes unpriced'] unless [nil, 0].include?(usage['cache_write_input_tokens'])
      return [nil, 'Inconsistent token subsets'] if invalid_reasoning?(usage['reasoning_output_tokens'], tokens[2])

      [tokens, nil]
    end

    # Time.iso8601 rolls an impossible date such as November 31 into the next month and reads
    # a time without an offset in the machine's zone, so both are refused first.
    def response_day(timestamp)
      return unless timestamp.is_a?(String) && timestamp.match?(UsageOptions::ISO_TIME)

      Date.iso8601(timestamp)
      Time.iso8601(timestamp).utc.strftime('%F')
    rescue ArgumentError
      nil
    end
  end
end
