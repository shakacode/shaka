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
    THRESHOLD_NOTE = 'OpenAI API estimates apply the 272K context threshold.'

    private

    def markdown(columns, reasons)
      <<~MARKDOWN

        Cost estimates are not invoices. Actual charge: UNKNOWN.

        <details>
        <summary>Cost scenarios</summary>

        #{intro(columns)}

        #{cost_table(columns)}

        #{footer(columns, reasons)}

        </details>
      MARKDOWN
    end

    def intro(columns)
      [rate_intro(columns), (native_intro if columns.any? { |column| column[:native] })].compact.join(' ')
    end

    def rate_intro(columns)
      bits = priced_rate_copy(columns)
      return if bits.empty? && columns.any? { |column| column[:native] }

      prefix = bits.empty? ? 'Configured-model estimates' : bits.join(', plus ')
      "#{prefix}, verified #{VERIFIED}."
    end

    def priced_rate_copy(columns)
      providers = priced_columns(columns).map { |column| column[:provider] }
      [
        ('Standard Codex credit and OpenAI API-equivalent rates' if providers.include?('openai')),
        ('Cursor on-demand list prices' if providers.include?('cursor'))
      ].compact
    end

    def native_intro
      'Pi recorded native nominal USD.'
    end

    def priced_columns(columns)
      columns.reject { |column| column[:native] }
    end

    def footer(columns, reasons)
      [reasons.uniq.join('; '), source_line(columns), (@threshold ? THRESHOLD_NOTE : nil)]
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

  # Metric-row cost table and source links for the models actually priced.
  module CostTable
    MODEL_SOURCES = {
      'gpt-5.6-terra' => '[Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra)',
      'gpt-5.6-sol' => '[Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol)',
      'gpt-6-astra' => '[Astra](https://developers.openai.com/api/docs/models/gpt-6-astra)',
      'grok-4.6' => '[Cursor Grok 4.6](https://cursor.com/docs/models/grok-4-6)'
    }.freeze
    CREDIT_SOURCE = '[Codex credit rates](https://learn.chatgpt.com/docs/pricing#token-rates)'
    CACHE_SOURCE = '[prompt-cache accounting](https://developers.openai.com/api/docs/guides/prompt-caching)'
    CURSOR_PRICING = '[Cursor model pricing](https://cursor.com/docs/models-and-pricing)'

    private

    def cost_table(columns)
      headers = cost_headers(columns)
      [line(['Metric', *headers]), line(['---'] * (headers.size + 1)), *estimate_rows(columns)].join("\n")
    end

    def estimate_rows(columns)
      rows = []
      if credits_row?(columns)
        rows << line(['Credits estimate', *columns.map { |column| show(column[:credits], 'credits') }])
      end
      rows << line(['USD estimate', *columns.map { |column| show(column[:api], '$') }])
    end

    def cost_headers(columns)
      labeled = columns.map { |column| setting_cells(column) }
      header_candidates(labeled).find { |names| names.uniq.size == names.size } ||
        labeled.map.with_index { |cells, index| "#{cells[0]}-#{index + 1}" }
    end

    def setting_cells(column)
      [column[:provider], column[:model], column[:routed], column[:effort]].map { |value| safe(value) }
    end

    def header_candidates(labeled)
      [1, 3, 2, 0].map { |index| labeled.map { |cells| cells[index] } } +
        [[1, 3], [0, 1, 3], [0, 1, 2, 3]].map do |indexes|
          labeled.map { |cells| indexes.map { |index| cells[index] }.join(' ') }
        end
    end

    def credits_row?(columns)
      priced_columns(columns).any? { |column| column[:provider] == 'openai' || column[:credits] }
    end

    def source_line(columns)
      links = source_links(columns)
      return if links.empty?

      "Sources: #{join_english(links)}."
    end

    def source_links(columns)
      priced = priced_columns(columns)
      providers = priced.map { |column| column[:provider] }
      [
        (CREDIT_SOURCE if providers.include?('openai')),
        *model_source_links(priced),
        (CACHE_SOURCE if providers.include?('openai')),
        (CURSOR_PRICING if providers.include?('cursor'))
      ].compact
    end

    def model_source_links(columns)
      columns.map { |column| MODEL_SOURCES[column[:model].to_s.sub(/-fast\z/, '')] }.uniq
    end

    def join_english(items)
      return items.first if items.size == 1
      return items.join(' and ') if items.size == 2

      "#{items[0..-2].join(', ')}, and #{items.last}"
    end

    def line(cells) = "| #{cells.join(' | ')} |"
  end

  # One cost column per configuration and billing mode.
  module CostColumns
    private

    def column(key, group, reasons)
      configuration, billing = key
      provider, model, routed, effort = configuration
      credits, api = priced_totals(group, reasons, provider)
      { provider: provider, model: billed_model(provider, billing, model), routed: routed, effort: effort,
        credits: credits, api: api, native: native_cost?(group) }
    end

    def priced_totals(group, reasons, provider)
      credits, credit_reason = total(group, :credits)
      api, api_reason = total(group, :api)
      reasons << credit_reason if credit_reason && keep_credit_reason?(provider, credits, group)
      reasons << api_reason if api_reason
      [credits, api]
    end

    def billed_model(provider, billing, model)
      provider == 'cursor' && billing == 'fast' && model.is_a?(String) ? "#{model}-fast" : model
    end

    def native_cost?(group)
      group.any? && group.all? do |record|
        value = record['usage'].is_a?(Hash) ? record['usage']['native_cost_usd'] : nil
        value.is_a?(Numeric) && value.finite? && value >= 0
      end
    end

    def keep_credit_reason?(provider, credits, group)
      credits || (provider == 'openai' && !native_cost?(group))
    end

    def blank_column
      { provider: nil, model: nil, routed: nil, effort: nil, credits: nil, api: nil, native: false }
    end
  end

  # Prices configured-model scenarios from disjoint per-response token categories.
  class CostEstimate
    include CursorCost
    include CostCopy
    include CostTable
    include CostColumns

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
      @threshold = false
      reasons = []
      groups = @responses.group_by { |record| [record['configuration'], record['billing_mode']] }
      columns = groups.map { |key, group| column(key, group, reasons) }
      columns = [blank_column] if columns.empty?
      markdown(columns, reasons)
    end

    private

    def total(group, mode)
      amounts = group.map { |record| price(record, mode) }
      reason = amounts.map(&:last).compact.first
      [reason ? nil : amounts.sum { |amount, _| amount }, reason]
    end

    # Every published rate here bills input inclusive of its cached and written subsets.
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
      return [nil, 'Cache-exclusive input is unpriced'] unless @inclusive_input

      provider, model = record['configuration']
      return [nil, 'Unsupported provider or configured model'] unless %w[openai cursor].include?(provider)

      tokens, reason = categories(record['usage'])
      return [nil, reason] if reason

      return openai_price(model, mode, tokens) if provider == 'openai'

      cursor_price(model, record['billing_mode'], mode, tokens)
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

    def valid_counters?(tokens)
      tokens.all? { |value| value.is_a?(Integer) && value >= 0 }
    end

    def invalid_reasoning?(reasoning, output)
      reasoning.is_a?(Integer) && (reasoning.negative? || reasoning > output)
    end
  end
end
