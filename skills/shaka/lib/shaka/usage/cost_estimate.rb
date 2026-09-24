# frozen_string_literal: true

require_relative 'rate_card'
require_relative 'cursor_cost'
require_relative 'anthropic_cost'
require_relative 'openai_cost'
require_relative 'cost_copy'
require_relative 'cost_table'
require_relative 'cost_columns'

module Shaka
  # Prices rate-card scenarios from disjoint per-response token categories, on the configured
  # model where a source records one and on the routed model where it does not.
  class CostEstimate
    include CursorCost
    include AnthropicCost
    include OpenAICost
    include CostCopy
    include CostTable
    include CostColumns

    def initialize(responses, inclusive_input: true, rate_card: nil)
      @responses = responses
      @inclusive_input = inclusive_input
      @rate_card = rate_card || RateCard.installed
    end

    def report
      @threshold = false
      @cursor_threshold = false
      reasons = []
      groups = @responses.group_by { |record| [record['configuration'], record['billing_mode']] }
      columns = groups.map { |key, group| column(key, group, reasons) }
      columns = [blank_column] if columns.empty?
      markdown(columns, reasons)
    end

    private

    def total(group, mode)
      amounts = group.map { |record| price(record, mode) }
      reason = amounts.filter_map(&:last).first
      [reason ? nil : amounts.sum { |amount, _| amount }, reason]
    end

    # The OpenAI and Cursor rates bill input inclusive of its cached and written subsets;
    # the Anthropic rates bill those three separately and are priced on their own path.
    def price(record, mode)
      native_price(record, mode) || configured_price(record, mode)
    end

    def native_price(record, mode)
      usage = record['usage']
      return unless usage.is_a?(Hash) && usage.key?('native_cost_usd')
      return [nil, 'Codex credit estimate unavailable for Pi'] if mode == :credits

      value = usage['native_cost_usd']
      return [nil, 'Native nominal cost unavailable'] unless value.is_a?(Numeric) && value.finite? && value >= 0

      [value, nil]
    end

    def configured_price(record, mode)
      provider, model = record['configuration']
      return anthropic_price(record, mode) if provider == 'anthropic' && !@inclusive_input
      return [nil, 'Cache-exclusive input is unpriced'] unless @inclusive_input
      return [nil, 'Unsupported provider or configured model'] unless %w[openai cursor].include?(provider)

      tokens, reason = categories(record['usage'])
      return [nil, reason] if reason

      return openai_price(model, mode, tokens) if provider == 'openai'

      cursor_price(model, record['billing_mode'], mode, tokens)
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

    def valid_counters?(tokens)
      tokens.all? { |value| value.is_a?(Integer) && value >= 0 }
    end

    def invalid_reasoning?(reasoning, output)
      reasoning.is_a?(Integer) && (reasoning.negative? || reasoning > output)
    end
  end
end
