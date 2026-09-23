# frozen_string_literal: true

module Shaka
  # Report copy for the rate-card cost scenarios.
  module CostCopy
    VERIFIED = '2026-09-23'
    CURSOR_VERIFIED = '2026-09-21'
    ANTHROPIC_VERIFIED = '2026-09-23'
    THRESHOLD_NOTE = 'OpenAI API estimates apply the 272K context threshold.'
    CURSOR_THRESHOLD_NOTE = 'Cursor Grok 4.7 estimates apply the 256K context threshold.'

    private

    def markdown(columns, reasons)
      parts = [cost_table(columns),
               'Cost estimates are not invoices. Actual charge: UNKNOWN.',
               intro(columns),
               footer(columns, reasons)].compact.reject { |part| part.to_s.strip.empty? }
      "#{parts.join("\n\n")}\n"
    end

    def intro(columns)
      [rate_intro(columns), (native_intro if columns.any? { |column| column[:native] })].compact.join(' ')
    end

    def rate_intro(columns)
      sentences = [rate_card_intro(columns), anthropic_intro(columns)].compact
      sentences.join(' ') unless sentences.empty?
    end

    def rate_card_intro(columns)
      sentences = rate_card_sentences(priced_columns(columns))
      "#{sentences.join('. ')}." unless sentences.empty?
    end

    def rate_card_sentences(priced)
      [
        ("Standard Codex credit and OpenAI API-equivalent rates, verified #{VERIFIED}" if openai_priced?(priced)),
        ("Cursor on-demand list prices, verified #{CURSOR_VERIFIED}" if cursor_priced?(priced))
      ].compact
    end

    def anthropic_intro(columns)
      return unless anthropic_priced?(priced_columns(columns))

      "Anthropic API list prices, verified #{ANTHROPIC_VERIFIED}. Uncached input, cache reads and " \
        'cache writes are separate charges, and a 1-hour cache write costs more than a 5-minute one. ' \
        'Standard-speed responses are priced; fast mode is priced for Opus models with a published rate.'
    end

    def openai_priced?(priced) = priced.any? { |column| openai_rated?(column) }
    def cursor_priced?(priced) = priced.any? { |column| cursor_rated?(column) }
    def anthropic_priced?(priced) = priced.any? { |column| anthropic_rated?(column) }

    def native_intro
      'Pi recorded native nominal USD.'
    end

    def priced_columns(columns)
      columns.reject { |column| column[:recorded_native] }
    end

    def openai_rated?(column)
      column[:provider] == 'openai' && OpenAICost::RATES.key?(column[:model].to_s)
    end

    def cursor_rated?(column)
      model = column[:model].to_s.delete_suffix('-fast')
      column[:provider] == 'cursor' && CursorCost::RATES.dig(model, column[:billing])
    end

    # Rate-card copy describes the provider and model pair's rate card, as it does for every
    # other provider, so it stays beside an UNKNOWN a response's own counters caused.
    def anthropic_rated?(column)
      return false unless column[:provider] == 'anthropic' && !@inclusive_input

      model = anthropic_rate_model(column)
      return false unless model

      column[:billing] == 'standard' ||
        (column[:billing] == 'fast' && AnthropicCost::FAST_MODELS.include?(model))
    end

    def anthropic_rate_model(column)
      [column[:routed], column[:model]].find { |name| AnthropicCost::RATES.key?(name.to_s) }&.to_s
    end

    def footer(columns, reasons)
      [reasons.uniq.join('; '), source_line(columns), (@threshold ? THRESHOLD_NOTE : nil),
       (@cursor_threshold ? CURSOR_THRESHOLD_NOTE : nil)]
        .compact.reject(&:empty?).join("\n")
    end

    def show(amount, unit)
      return 'UNKNOWN' unless amount

      formatted = format('%.6f', amount)
      unit == '$' ? "$#{formatted}" : formatted
    end

    def safe(value)
      value.is_a?(String) && value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._:-]{0,79}\z/) ? value : 'UNKNOWN'
    end
  end
end
