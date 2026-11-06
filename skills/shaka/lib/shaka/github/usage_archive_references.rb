# frozen_string_literal: true

module Shaka
  # Checks the complete ordered inventory before any archive data reaches carry.
  module UsageArchiveReferences
    INVENTORY_PREFIX = '<!-- shaka:usage-archive-inventory '
    INVENTORY = /<!-- shaka:usage-archive-inventory ([0-9a-f]{64}) -->\n/

    private

    def check_archive_format(body, region)
      markers = [body.include?(Publishing::ARCHIVE_GUARD), region.to_s.include?(UsageArchive::PREFIX),
                 region.to_s.include?(UsageArchive::END_MARK), region.to_s.include?(INVENTORY_PREFIX)]
      return if markers.none? || markers.all?

      raise Error, 'Usage archive references are missing or malformed; restore them before publishing.'
    end

    def inventory_digest(refs)
      Digest::SHA256.hexdigest(JSON.generate(refs.map { |ref| ref.values_at('comments', 'sha256', 'record') }))
    end

    def inventory_line(refs) = "#{INVENTORY_PREFIX}#{inventory_digest(refs)} -->\n"

    def check_inventory(region, refs)
      hashes = region.scan(INVENTORY).flatten
      return if region.scan(INVENTORY_PREFIX).size == 1 && hashes == [inventory_digest(refs)]

      raise Error, 'Usage archive inventory changed; restore it before publishing.'
    end

    def reference_map(blocks, ids, digest)
      blocks.each_with_index.to_h do |block, index|
        [block, { 'comments' => ids, 'sha256' => digest, 'record' => index }]
      end
    end

    def reference(json)
      value = JSON.parse(json)
      unless value.is_a?(Hash) && value.keys.sort == %w[comments record sha256] && valid_reference?(value)
        raise Error, 'Malformed usage archive reference.'
      end

      value
    end

    def valid_reference?(value)
      ids, digest, index = value.values_at('comments', 'sha256', 'record')
      valid_ids?(ids) && digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/) &&
        index.is_a?(Integer) && index >= 0
    end

    def valid_ids?(ids)
      ids.is_a?(Array) && ids.size.between?(1, 128) && ids.all? { |id| id.is_a?(Integer) && id.positive? }
    end
  end
end
