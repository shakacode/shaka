# frozen_string_literal: true

module Shaka
  # Checks the complete ordered inventory before any archive data reaches carry.
  module UsageArchiveReferences
    INVENTORY_PREFIX = '<!-- shaka:usage-archive-inventory '
    INVENTORY = /<!-- shaka:usage-archive-inventory ([0-9a-f]{64}) -->\n/
    # The usage section joins its reports with a blank line; a grouped reference restores exactly that.
    SEPARATOR = "\n\n"
    # A single `record` reference is the format before grouping; the helpers that wrote it refuse `records`.
    SHAPES = [%w[comments record sha256], %w[comments records sha256]].freeze

    private

    def check_archive_format(body, region)
      markers = [body.include?(Publishing::ARCHIVE_GUARD), region.to_s.include?(UsageArchive::PREFIX),
                 region.to_s.include?(UsageArchive::END_MARK), region.to_s.include?(INVENTORY_PREFIX)]
      return if markers.none? || markers.all?

      raise Error, 'Usage archive references are missing or malformed; restore them before publishing.'
    end

    def inventory_digest(refs)
      entries = refs.map { |ref| [*ref.values_at('comments', 'sha256'), ref.fetch('records') { ref['record'] }] }
      Digest::SHA256.hexdigest(JSON.generate(entries))
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

    # Splits the region into [text before, blocks, reference] runs, ending with the text after the last block.
    # Adjacent table records from one archive share a reference, so the description grows by one reference
    # per archive instead of one per record. A report with visible text keeps its own reference and display.
    def runs(region, references)
      pieces, tail = pieces(region)
      grouped = pieces.chunk_while { |(_, before), (gap, after)| groupable?(before, gap, after, references) }
      grouped.map do |run|
        blocks = run.map(&:last)
        [run.first.first, blocks, grouped_reference(blocks, references)]
      end << [tail, [], nil]
    end

    def groupable?(before, gap, after, references)
      gap == SEPARATOR && hidden?(before) && hidden?(after) && same_archive?(references[before], references[after])
    end

    def pieces(region)
      cursor = 0
      pieces = region.to_enum(:scan, UsageRecords::BLOCK).map do
        match = Regexp.last_match
        gap = region[cursor...match.begin(0)]
        cursor = match.end(0)
        [gap, match[0]]
      end
      [pieces, region[cursor..]]
    end

    def grouped_reference(blocks, references)
      first = references[blocks.first]
      return first unless first && hidden?(blocks.first)

      first.slice('comments', 'sha256').merge('records' => blocks.map { |block| references[block].fetch('record') })
    end

    def same_archive?(first, second)
      first && second && first.values_at('comments', 'sha256') == second.values_at('comments', 'sha256')
    end

    # A table record keeps only hidden columns and notes, which the table and pricing notes already show.
    def hidden?(block) = inner(block).gsub(/<!--.*?-->/m, '').strip.empty?

    def indices(ref) = ref.fetch('records') { [ref.fetch('record')] }

    def reference(json)
      value = JSON.parse(json)
      unless value.is_a?(Hash) && SHAPES.include?(value.keys.sort) && valid_reference?(value)
        raise Error, 'Malformed usage archive reference.'
      end

      value
    end

    def valid_reference?(value)
      ids, digest = value.values_at('comments', 'sha256')
      valid_ids?(ids) && digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/) && valid_indices?(indices(value))
    end

    def valid_indices?(indices)
      indices.is_a?(Array) && !indices.empty? && indices.all? { |index| index.is_a?(Integer) && index >= 0 }
    end

    def valid_ids?(ids)
      ids.is_a?(Array) && ids.size.between?(1, 128) && ids.all? { |id| id.is_a?(Integer) && id.positive? }
    end
  end
end
