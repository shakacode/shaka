# frozen_string_literal: true

module Shaka
  # One row per report label, one column per metric any report measured, and a total.
  # Numbers are rounded for reading; the hidden record copies keep the reported text.
  class UsageRows
    METRICS = [
      ['usd', 'USD'],
      ['credits', 'Credits'],
      ['input', 'Input'],
      ['cached_input', 'Cached input'],
      ['output', 'Output'],
      ['reasoning_output', 'Reasoning'],
      ['cache_writes', 'Cache writes']
    ].freeze
    ROUTE = %w[label provider model routed effort].freeze
    LEGEND = [
      [:unreported?, '— not reported'],
      [:minimum?, '+ some usage not reported, so the amount is a minimum'],
      [:earlier?, 'reports from before this table are listed below and not counted']
    ].freeze
    AMOUNT = /\A(\$)?(\d+(?:\.\d+)?)( \(partial\))?\z/

    # A sum over values some of which went unreported, or an estimate marked partial.
    Amount = Struct.new(:value, :lower_bound)

    # Earlier reports shown below the table are not parsed, so the total is a minimum.
    def initialize(columns, earlier: false)
      @earlier = earlier
      @rows = report_rows(columns)
      @rows << ['**Total**', sums(columns)] if @rows.size > 1
      @metrics = METRICS.select { |key, _label| @rows.any? { |_label, amounts| amounts[key] } }
    end

    def table
      header = ['Report', *@metrics.map(&:last)]
      separator = ['---', *(['---:'] * @metrics.size)]
      body = @rows.map { |label, amounts| [escape(label), *@metrics.map { |key, _| shown(key, amounts[key]) }] }
      [header, separator, *body].map { |row| "| #{row.join(' | ')} |" }.join("\n")
    end

    def summary
      usd = @rows.last.last['usd']
      usd &&= Amount.new(usd.value, true) if @earlier
      usd && "#{shown('usd', usd)} estimated"
    end

    def legend
      cells = @rows.flat_map { |_label, amounts| @metrics.map { |key, _| amounts[key] } }
      notes = LEGEND.filter_map { |test, text| text if send(test, cells) }
      "_#{notes.join('; ')}._" unless notes.empty?
    end

    private

    def unreported?(cells) = cells.include?(nil)
    def minimum?(cells) = cells.compact.any?(&:lower_bound)
    def earlier?(_cells) = @earlier

    # Labels are only unique within one report, so rows also match on the route.
    # A label shared by different routes gains the model and effort that tell them apart.
    def report_rows(columns)
      groups = columns.group_by { |column| column.values_at(*ROUTE) }.values
      shared = groups.map { |group| group.first['label'] }.tally.reject { |_label, count| count == 1 }
      groups.map { |group| [row_label(group, shared), sums(group)] }
    end

    def row_label(group, shared)
      label = group.first['label']
      label = "#{label} (#{route_name(group.first)})" if shared.key?(label)
      group.size > 1 ? "#{label} ×#{group.size}" : label
    end

    def route_name(column)
      model = [column['routed'], column['model'], column['provider']].find { |value| value != 'UNKNOWN' }
      [model, column['effort']].reject { |value| value.nil? || value == 'UNKNOWN' }.join(' ')
    end

    def sums(group)
      METRICS.to_h { |key, _label| [key, sum(group.map { |column| amount(column[key]) })] }
    end

    def sum(amounts)
      known = amounts.compact
      return if known.empty?

      Amount.new(known.sum(&:value), known.size < amounts.size || known.any?(&:lower_bound))
    end

    def amount(text)
      match = AMOUNT.match(text)
      return unless match

      Amount.new(match[2].include?('.') ? match[2].to_f : match[2].to_i, !match[3].nil?)
    end

    def shown(key, amount)
      return '—' unless amount

      text = case key
             when 'usd' then usd(amount.value)
             when 'credits' then format('%.2f', amount.value)
             else grouped(amount.value.to_i)
             end
      amount.lower_bound ? "#{text}+" : text
    end

    def usd(value)
      return '<$0.01' if value.positive? && value < 0.005

      whole, cents = format('%.2f', value).split('.')
      "$#{grouped(whole.to_i)}.#{cents}"
    end

    def grouped(number) = number.to_s.reverse.scan(/\d{1,3}/).join(',').reverse

    def escape(text) = text.gsub(/[\\|]/) { |character| "\\#{character}" }
  end
end
