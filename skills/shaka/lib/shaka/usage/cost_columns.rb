# frozen_string_literal: true

module Shaka
  # One cost column per configuration and billing mode.
  module CostColumns
    private

    def column(key, group, reasons)
      configuration, billing = key
      provider, model, routed, effort = configuration
      credits, api = priced_totals(group, reasons, provider, model)
      { provider: provider, model: billed_model(provider, billing, model),
        routed: billed_routed(provider, billing, routed), effort: effort,
        billing: billing, credits: credits, api: api, native: native_cost?(group),
        recorded_native: native_recorded?(group) }
    end

    def priced_totals(group, reasons, provider, model)
      credits, credit_reason = total(group, :credits)
      api, api_reason = total(group, :api)
      reasons << credit_reason if credit_reason && keep_credit_reason?(provider, model, credits, group)
      reasons << api_reason if api_reason
      [credits, api]
    end

    def billed_model(provider, billing, model)
      provider == 'cursor' && billing == 'fast' && model.is_a?(String) ? "#{model}-fast" : model
    end

    # Anthropic names no configured model, so its fast column is distinguished on the routed one.
    def billed_routed(provider, billing, routed)
      provider == 'anthropic' && billing == 'fast' && routed.is_a?(String) ? "#{routed}-fast" : routed
    end

    def native_cost?(group)
      group.any? && group.all? do |record|
        value = record['usage'].is_a?(Hash) ? record['usage']['native_cost_usd'] : nil
        value.is_a?(Numeric) && value.finite? && value >= 0
      end
    end

    def native_recorded?(group)
      group.any? { |record| record['usage'].is_a?(Hash) && record['usage'].key?('native_cost_usd') }
    end

    def keep_credit_reason?(provider, model, credits, group)
      credits || (provider == 'openai' && OpenAICost::RATES.key?(model.to_s) && !native_recorded?(group))
    end

    def blank_column
      { provider: nil, model: nil, routed: nil, effort: nil, billing: nil, credits: nil, api: nil, native: false,
        recorded_native: false }
    end
  end
end
