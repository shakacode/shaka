# frozen_string_literal: true

module Shaka
  class Seam
    # Preserves both snapshots if installing a new recovery copy fails.
    class PrivateRecovery
      private

      def install_copy(copy, inventory)
        current, previous, aside = rotation_paths
        moves = []
        move_for_rotation(previous, aside, moves) if File.exist?(previous)
        move_for_rotation(current, previous, moves) if File.exist?(current)
        move_for_rotation(copy, current, moves)
        write_manifest(inventory)
        FileUtils.rm_rf(aside)
      rescue SystemCallError
        moves&.reverse_each { |from, to| File.rename(to, from) }
        raise
      end

      def rotation_paths
        [File.join(@storage, 'current'), File.join(@storage, 'previous'),
         File.join(@storage, "previous-#{SecureRandom.hex(8)}")]
      end

      def move_for_rotation(from, to, moves)
        File.rename(from, to)
        moves << [from, to]
      end
    end
  end
end
