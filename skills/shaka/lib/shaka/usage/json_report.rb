# frozen_string_literal: true

require 'json'
require_relative 'cost_estimate'

module Shaka
  # Machine-readable usage columns for the description table.
  module UsageJsonReport
    def self.format_option(flags, options)
      flags.on('--format NAME', %w[markdown json], 'markdown (default) or json') do |value|
        options[:format] = value
      end
    end

    JSON_METRICS = [
      %w[input input_tokens],
      %w[cached_input cached_input_tokens],
      %w[output output_tokens],
      %w[reasoning_output reasoning_output_tokens],
      %w[cache_writes cache_write_input_tokens]
    ].freeze

    def json_document
      estimate = CostEstimate.new(cost_responses, inclusive_input: @source.class::INCLUSIVE_INPUT,
                                                  rate_card: selected_rate_card)
      data = estimate.snapshot
      columns = json_columns(estimate, data)
      {
        'note' => json_note(estimate, data),
        'columns' => columns,
        'record' => record_identity.merge('columns' => columns)
      }
    end

    private

    def json_note(estimate, data)
      [estimate.narrative_for(data), reviewer_coverage,
       "Native usage is PARTIAL. #{count}. Scope: #{turn_scope}."].join("\n\n")
    end

    def json_columns(estimate, data)
      headers = estimate.column_headers(data[:columns])
      data[:columns].each_with_index.map do |column, index|
        json_column(estimate, column, data[:groups][index] || [], headers.fetch(index))
      end
    end

    def json_column(estimate, column, group, header)
      cells = {
        'label' => "#{header} #{@options[:contribution]}",
        'provider' => safe(column[:provider]), 'model' => safe(column[:model]),
        'routed' => safe(column[:routed]), 'effort' => safe(column[:effort]),
        'credits' => estimate.display(column, :credits, 'credits'),
        'usd' => estimate.display(column, :api, '$')
      }
      cells.merge(JSON_METRICS.to_h { |name, field| [name, token_total(group, field)] })
    end

    def token_total(group, field)
      values = group.map { |record| record['usage'].is_a?(Hash) ? record['usage'][field] : nil }
      countable?(values) ? values.sum.to_s : 'UNKNOWN'
    end
  end
end
