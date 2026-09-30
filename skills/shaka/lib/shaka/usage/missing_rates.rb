# frozen_string_literal: true

require_relative 'cost_estimate'

module Shaka
  # A missing entry qualifies only when the remaining billing inputs are usable.
  class MissingRates < CostEstimate
    PUBLIC_MODEL = {
      'openai' => /\A(?:gpt-\d+(?:\.\d+)?(?:-(?:sol|terra|astra|luna|mini|nano|pro|codex))?|o\d+(?:-(?:mini|pro))?)\z/,
      'anthropic' => /\Aclaude-(?:opus|sonnet|haiku|fable)-\d[a-z0-9.-]*\z/,
      'cursor' => /\Agrok-\d[a-z0-9.-]*\z/
    }.freeze

    def gaps
      @responses.flat_map { |record| missing(record) }.uniq.sort
    end

    private

    def missing(record)
      return [] unless usable_record?(record)

      provider, model = identity(record['configuration'])
      return [] unless public_identity?(provider, model)

      modes = provider == 'anthropic' ? anthropic_modes(model, record) : inclusive_modes(provider, model, record)
      modes.map { |mode| [provider, model, mode] }
    end

    def usable_record?(record)
      return false unless record.is_a?(Hash) && record['configuration'].is_a?(Array)

      usage = record['usage']
      return false unless usage.is_a?(Hash) && !usage.key?('native_cost_usd')

      reasoning = usage['reasoning_output_tokens']
      reasoning.nil? || reasoning.is_a?(Integer)
    end

    def identity(configuration)
      provider, configured, routed = configuration
      [provider, provider == 'anthropic' && configured == 'UNKNOWN' ? routed : configured]
    end

    def public_identity?(provider, model)
      model.is_a?(String) && model.size <= 80 && PUBLIC_MODEL[provider]&.match?(model)
    end

    def anthropic_modes(_model, record)
      return [] if @inclusive_input || record['billing_mode'] != 'standard'
      return [] if @rate_card.anthropic_name(*record['configuration'].values_at(2, 1), record['billing_mode'])

      anthropic_categories(record['usage']).last ? [] : ['standard']
    end

    def inclusive_modes(provider, model, record)
      return [] unless @inclusive_input

      tokens, reason = categories(record['usage'])
      return [] if reason
      return openai_modes(model, tokens) if provider == 'openai'

      cursor_modes(model, record['billing_mode'])
    end

    def cursor_modes(model, billing)
      %w[standard fast].include?(billing) && !@rate_card.cursor_model?(model, billing) ? [billing] : []
    end

    def openai_modes(model, tokens)
      modes = tokens[2].zero? ? %w[api credits] : ['api']
      modes.reject { |mode| @rate_card.openai_rate(model, mode) }
    end
  end
end
