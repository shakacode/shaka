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

  # Anthropic list prices, which bill uncached input, cache reads and cache writes separately.
  module AnthropicCost
    # Per million tokens: input, cache read, 5-minute cache write, 1-hour cache write, output.
    # Every model Anthropic still serves outside limited-availability programs; retired models
    # are omitted because no current session routes to one.
    RATES = {
      'claude-fable-5-1' => %w[10 0.25 12.5 20 50],
      'claude-fable-5' => %w[10 1 12.5 20 50],
      'claude-opus-5' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-8' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-7' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-6' => %w[5 0.5 6.25 10 25],
      'claude-opus-4-5' => %w[5 0.5 6.25 10 25],
      'claude-sonnet-5' => %w[2 0.2 2.5 4 10],
      'claude-sonnet-4-6' => %w[3 0.3 3.75 6 15],
      'claude-sonnet-4-5' => %w[3 0.3 3.75 6 15],
      'claude-haiku-4-5' => %w[1 0.1 1.25 2 5]
    }.freeze
    # Web search bills $10 per 1,000 requests on top of tokens; web fetch adds no charge.
    # Readers report no searches as zero, so a count that is absent here was never established.
    SEARCH_RATE = Rational(1, 100)

    private

    # Claude Code records only the routed model; exports that name a configured model use that.
    def anthropic_rate(configuration)
      return unless configuration.is_a?(Array)

      _provider, model, routed = configuration
      RATES[[routed, model].find { |name| RATES.key?(name) }]
    end

    def anthropic_price(record, mode)
      return [nil, 'Codex credits do not price Anthropic'] if mode == :credits

      rate = anthropic_rate(record['configuration'])
      return [nil, 'Unsupported provider or configured model'] unless rate

      speed = record['billing_mode']
      return [nil, speed_reason(speed)] unless speed == 'standard'

      priced, reason = anthropic_categories(record['usage'])
      reason ? [nil, reason] : [anthropic_bill(priced, rate), nil]
    end

    # Fast mode bills at its own rates, and a source that records no speed establishes neither.
    def speed_reason(speed)
      speed == 'fast' ? 'Anthropic fast-mode rates are not published here' : 'Billing speed UNKNOWN'
    end

    def anthropic_bill(priced, rate)
      tokens, searches = priced
      (tokens.zip(rate).sum { |count, price| count * Rational(price) } / 1_000_000) + (searches * SEARCH_RATE)
    end

    def anthropic_categories(usage)
      return [nil, 'Incomplete billable token categories'] unless usage.is_a?(Hash)

      counters = %w[input_tokens cached_input_tokens cache_write_input_tokens output_tokens].map { |key| usage[key] }
      return [nil, 'Incomplete billable token categories'] unless valid_counters?(counters)

      input, cached, writes, output = counters
      split = write_split(usage, writes)
      searches = usage['web_search_requests']
      reason = anthropic_reason(usage, writes, split, [searches, output])
      reason ? [nil, reason] : [[[input, cached, *split, output], searches], nil]
    end

    def anthropic_reason(usage, writes, split, tools)
      searches, output = tools
      anthropic_subset_reason(writes, split, usage['reasoning_output_tokens'], output) ||
        ('Server tool usage UNKNOWN' unless valid_counters?([searches]))
    end

    # A zero write total already establishes both TTL categories, however few the transcript names.
    def write_split(usage, writes)
      split = %w[cache_write_5m_input_tokens cache_write_1h_input_tokens].map { |key| usage[key] }
      writes.zero? ? split.map { |count| count || 0 } : split
    end

    # The two cache-write rates differ, so only a split that accounts for the whole total is priced.
    def anthropic_subset_reason(writes, split, reasoning, output)
      return 'Cache-write TTL split UNKNOWN' if split.any?(&:nil?)
      return 'Inconsistent token subsets' unless valid_counters?(split) && split.sum == writes

      'Inconsistent token subsets' if invalid_reasoning?(reasoning, output)
    end
  end

  # Report copy for the rate-card cost scenarios.
  module CostCopy
    VERIFIED = '2026-09-16'
    ANTHROPIC_VERIFIED = '2026-09-19'
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
      sentences = [rate_card_intro(columns), anthropic_intro(columns)].compact
      sentences.join(' ') unless sentences.empty?
    end

    def rate_card_intro(columns)
      bits = priced_rate_copy(columns)
      "#{bits.join(', plus ')}, verified #{VERIFIED}." unless bits.empty?
    end

    def anthropic_intro(columns)
      return unless anthropic_priced?(priced_columns(columns))

      "Anthropic API list prices, verified #{ANTHROPIC_VERIFIED}. Uncached input, cache reads and " \
        'cache writes are separate charges, and a 1-hour cache write costs more than a 5-minute one. ' \
        'Only responses recorded at standard speed are priced.'
    end

    def priced_rate_copy(columns)
      priced = priced_columns(columns)
      [
        ('Standard Codex credit and OpenAI API-equivalent rates' if openai_priced?(priced)),
        ('Cursor on-demand list prices' if cursor_priced?(priced))
      ].compact
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
      column[:provider] == 'openai' && CostEstimate::RATES.key?(column[:model].to_s)
    end

    def cursor_rated?(column)
      model = column[:model].to_s.sub(/-fast\z/, '')
      column[:provider] == 'cursor' && CursorCost::RATES.dig(model, column[:billing])
    end

    # Rate-card copy describes the provider and model pair's rate card, as it does for every
    # other provider, so it stays beside an UNKNOWN a response's own counters caused.
    def anthropic_rated?(column)
      column[:provider] == 'anthropic' && !@inclusive_input && column[:billing] == 'standard' &&
        [column[:routed], column[:model]].any? { |name| AnthropicCost::RATES.key?(name.to_s) }
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
    ANTHROPIC_PRICING = '[Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)'

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
      candidates = header_candidates(labeled)
      distinct(candidates.reject { |names| names.include?('UNKNOWN') }) || distinct(candidates) ||
        labeled.map.with_index { |cells, index| "#{cells[0]}-#{index + 1}" }
    end

    def distinct(candidates)
      candidates.find { |names| names.uniq.size == names.size }
    end

    def setting_cells(column)
      [column[:provider], column[:model], column[:routed], column[:effort]].map { |value| safe(value) }
    end

    def header_candidates(labeled)
      [1, 2, 3, 0].map { |index| labeled.map { |cells| cells[index] } } +
        [[1, 3], [0, 1, 3], [0, 1, 2, 3]].map do |indexes|
          labeled.map { |cells| indexes.map { |index| cells[index] }.join(' ') }
        end
    end

    def credits_row?(columns)
      priced_columns(columns).any? { |column| openai_rated?(column) || column[:credits] }
    end

    def source_line(columns)
      links = source_links(columns)
      return if links.empty?

      "Sources: #{join_english(links)}."
    end

    def source_links(columns)
      priced = priced_columns(columns)
      [*rate_card_links(priced), (CURSOR_PRICING if cursor_priced?(priced)),
       (ANTHROPIC_PRICING if anthropic_priced?(priced))].compact
    end

    def rate_card_links(priced)
      return model_source_links(priced) unless openai_priced?(priced)

      [CREDIT_SOURCE, *model_source_links(priced), CACHE_SOURCE]
    end

    def model_source_links(columns)
      columns.filter_map do |column|
        next unless openai_rated?(column) || cursor_rated?(column)

        MODEL_SOURCES[column[:model].to_s.sub(/-fast\z/, '')]
      end.uniq
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
      credits || (provider == 'openai' && CostEstimate::RATES.key?(model.to_s) && !native_recorded?(group))
    end

    def blank_column
      { provider: nil, model: nil, routed: nil, effort: nil, billing: nil, credits: nil, api: nil, native: false,
        recorded_native: false }
    end
  end

  # Prices rate-card scenarios from disjoint per-response token categories, on the configured
  # model where a source records one and on the routed model where it does not.
  class CostEstimate
    include CursorCost
    include AnthropicCost
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
