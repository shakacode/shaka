# frozen_string_literal: true

require_relative '../publication/usage_rows'

module Shaka
  # Compacts a deduplicated journal for the description; comments retain each native response.
  module UsageJournalSummary
    ROUTE = %w[label provider model routed effort].freeze

    module_function

    def compact(records)
      records.group_by { |record| group_key(record) }.values.map { |group| summarize(group) }
    end

    def group_key(record)
      record.values_at('host', 'contribution', 'complete', 'note', 'covers_task') +
        [record['commits'].sort, record['columns'][0].values_at(*ROUTE)]
    end

    def summarize(group)
      columns = group.map { |record| record['columns'][0] }
      fields = %w[sources responses].to_h { |key| [key, group.flat_map { |record| record[key] }.uniq] }
      fields['from'] = boundary(group, 'from', :min)
      fields['to'] = boundary(group, 'to', :max)
      group.first.merge(fields, 'columns' => [sum_column(columns)])
    end

    def boundary(group, key, direction)
      stamps = group.map { |record| UsageRecords.time(record[key]) }
      return 'UNKNOWN' if stamps.include?(nil)

      stamps.public_send(direction).utc.iso8601(6)
    end

    def sum_column(columns)
      metrics = UsageRows::METRICS.to_h { |key, _label| [key, sum_metric(columns, key)] }
      columns.first.slice(*ROUTE).merge(metrics)
    end

    def decimal_total(amounts)
      scale = amounts.map { |match| match[2].partition('.')[2].length }.max
      units = amounts.sum { |match| (Rational(match[2]) * (10**scale)).to_i }
      decimal_text(units, scale)
    end

    def decimal_text(units, scale)
      return units.to_s if scale.zero?

      digits = units.to_s.rjust(scale + 1, '0')
      "#{digits[...-scale]}.#{digits[-scale..]}"
    end

    def sum_metric(columns, key)
      amounts = columns.filter_map { |column| UsageRows::AMOUNT.match(column[key]) }
      return 'UNKNOWN' if amounts.empty?

      value = decimal_total(amounts)
      value = "$#{value}" if key == 'usd'
      partial = amounts.size < columns.size || amounts.any? { |match| match[3] }
      partial ? "#{value} (partial)" : value
    end
  end
end
