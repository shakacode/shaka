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
    AMOUNT = /\A(\$)?(\d+(?:\.\d+)?)( \(partial\))?\z/

    # A sum over values some of which went unreported, or an estimate marked partial.
    Amount = Struct.new(:value, :lower_bound)

    def initialize(columns)
      @groups = columns.group_by { |column| column['label'] }
      @rows = @groups.map { |label, group| [group.size > 1 ? "#{label} ×#{group.size}" : label, sums(group)] }
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
      usd && "#{shown('usd', usd)} estimated"
    end

    def legend
      cells = @rows.flat_map { |_label, amounts| @metrics.map { |key, _| amounts[key] } }
      notes = [('— not reported' if cells.include?(nil)),
               ('+ some usage not reported, so the amount is a minimum' if cells.compact.any?(&:lower_bound))]
      "_#{notes.compact.join('; ')}._" if notes.any?
    end

    private

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
