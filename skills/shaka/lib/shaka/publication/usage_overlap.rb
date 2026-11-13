# frozen_string_literal: true

module Shaka
  # Preserves earlier counters when private identities are unavailable for comparison.
  module UsageOverlap
    private

    # An identical public snapshot needs one display record even when native coverage is unknown.
    def remove_repeated_public_snapshots(carried)
      repeated = fresh_blocks.map { |block| PublicUsageIdentity.redact(block) }.tally
      carried.reject do |block|
        next false unless repeated.fetch(block, 0).positive?

        repeated[block] -= 1
        true
      end
    end

    def overlapping_carried
      @overlapping_carried ||= find_overlapping_carried
    end

    def find_overlapping_carried
      blocks = @carried.grep(UsageDetails::HIDDEN)
      identities = blocks.map { |block| carried_identity(block) }
      fresh = measured_identities(@records.map { |entry| entry.fetch('identity') })
      blocks.filter_map.with_index do |block, index|
        old = identities[index]
        block if old && overlaps?(old, fresh + others_at(identities, index))
      end
    end

    def carried_identity(block)
      identity = UsageRecords.text_records(block).first
      marker = block[UsageRecords::BLOCK, 1]
      identity['identity_withheld'] = true if identity && JSON.parse(marker)['identity_withheld'] == true
      identity
    end

    def others_at(identities, index)
      others = identities.dup
      others.delete_at(index)
      measured_identities(others.compact)
    end

    def measured_identities(identities)
      identities.select { |identity| identity['identity_withheld'] || identity.fetch('responses').any? }
    end

    def overlaps?(old, candidates)
      candidates.any? do |other|
        old['host'] == other['host'] && matching_contribution?(old, other) &&
          same_measurement?(old, other)
      end
    end

    def same_measurement?(old, other)
      unless old['identity_withheld']
        return false if old == other

        return old.fetch('responses').intersect?(other.fetch('responses'))
      end

      UsageRecords.intervals_touch?(old, other)
    end

    def matching_contribution?(old, other)
      old['contribution'] == other['contribution'] ||
        [old, other].any? { |record| record['contribution'] == 'shared-planning' }
    end

    def overlapping_reports
      return [] if overlapping_carried.empty?

      tables = overlapping_carried.map do |block|
        UsageRows.new(columns(parse_hidden(block[UsageDetails::HIDDEN, 1]))).table
      end
      ['Earlier snapshots may overlap the current reports. Their counts are listed separately.', *tables]
    end
  end
end
