# frozen_string_literal: true

require 'digest'

module Shaka
  module Evaluation
    # Recompute native Git identities so a truncated inventory cannot appear complete.
    module DeliveryWorkflowTree
      MODES = { 33_188 => 'blob', 33_261 => 'blob', 16_384 => 'tree', 40_960 => 'blob', 57_344 => 'commit' }.freeze

      private

      def revision?(value) = value.is_a?(String) && /\A[0-9a-f]{40}\z/.match?(value)

      def native_entries(tree)
        rows = tree.fetch('entries')
        unavailable unless tree.fetch('__typename') == 'Tree' && revision?(tree.fetch('oid')) && entries?(rows)
        unavailable unless git_digest('tree', tree_bytes(rows)) == tree.fetch('oid')
        rows
      end

      def entries?(rows)
        rows.is_a?(Array) && rows.size <= 100 && rows.all? { native_entry?(it) } &&
          rows.map { it.fetch('name') }.uniq.size == rows.size
      end

      def tree_bytes(rows)
        rows.sort_by { (it.fetch('name') + (it['type'] == 'tree' ? '/' : '')).b }.map do |row|
          "#{row.fetch('mode').to_s(8)} #{row.fetch('name')}\0".b + [row.fetch('oid')].pack('H*')
        end.join.b
      end

      def native_entry?(row)
        entry_name?(row.fetch('name')) && MODES.key?(row.fetch('mode')) &&
          MODES[row.fetch('mode')] == row.fetch('type') && revision?(row.fetch('oid'))
      end

      def entry_name?(name)
        name.is_a?(String) && name.valid_encoding? && !name.empty? && !%w[. ..].include?(name) &&
          !name.include?('/') && !name.include?("\0")
      end

      def workflow_text(entry)
        row = entry.fetch('object')
        text = row.fetch('text')
        unavailable unless workflow_blob?(row, entry) && text.is_a?(String) && text.valid_encoding?
        unavailable unless text.bytesize == row.fetch('byteSize') && git_digest('blob', text.b) == row.fetch('oid')
        text
      end

      def workflow_blob?(row, entry)
        [33_188, 33_261].include?(entry.fetch('mode')) && row.fetch('__typename') == 'Blob' &&
          row.fetch('oid') == entry.fetch('oid') && row.fetch('isBinary') == false && row.fetch('isTruncated') == false
      end

      def git_digest(type, bytes) = Digest::SHA1.hexdigest("#{type} #{bytes.bytesize}\0".b + bytes)
    end
  end
end
