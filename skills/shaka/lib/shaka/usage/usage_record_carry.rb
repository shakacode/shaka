# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Carries earlier usage reports when the new description supplies structured records.
  module UsageRecordCarry
    module_function

    def structured_usage(content)
      usage = content.is_a?(Hash) ? content['usage'] : nil
      usage if usage.is_a?(Hash)
    end

    def apply(records, content, usage, existing, stats)
      fresh = Array(usage['records']).map { |fields| identity!(without_columns(fields)) }
      region = records.managed_region(existing)
      return [content, stats] unless region

      kept = records.carried(region, '', stats, fresh)
      return [content, stats] if kept.empty?

      [content.merge('usage' => usage.except('carried').merge('carried' => kept.join("\n\n"))), stats]
    end

    def identity(fields)
      return unless fields.is_a?(Hash) && UsageRecords::FIELDS.all? { |key| fields.key?(key) }
      return unless %w[sources responses].all? { |key| fields[key].is_a?(Array) }

      fields
    end

    def identity!(fields)
      identity(fields) || raise(Error, 'Publication usage record is missing identity fields.')
    end

    def without_columns(fields)
      fields.is_a?(Hash) ? fields.except('columns') : fields
    end
  end
end
