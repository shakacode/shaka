# frozen_string_literal: true

require_relative '../error'
require_relative 'prose'

module Shaka
  module Writing
    # Refuses sentences copied between a description and its walkthrough. The two serve
    # different readers, so a copied run means one reader is being handed the other's
    # resolution, and republishing the walkthrough at a new head leaves the copy stale.
    #
    # Eight-word runs and the five-percent threshold come from shakacode/shaka#128, whose
    # published pair shared ten of its runs, 1.6 percent, all of them real copying.
    class Duplication
      SIZE = 8
      THRESHOLD = 0.05
      SHOWN = 5

      def initialize(text, sibling)
        @text = text
        @sibling = sibling
      end

      # An absent sibling is the ordinary first publication, never a failure.
      def check(label)
        return if @sibling.to_s.strip.empty?

        shared = (mine & Prose.shingles(@sibling, SIZE)).to_a
        ratio = shared.size.fdiv([mine.size, 1].max)
        return if ratio <= THRESHOLD

        raise Error, message(label, ratio, shared)
      end

      private

      def mine = @mine ||= Prose.shingles(@text, SIZE)

      def message(label, ratio, shared)
        "This #{label} repeats #{format('%.1f', ratio * 100)} percent of its own eight-word runs from the " \
          "published sibling, above the #{(THRESHOLD * 100).to_i} percent limit; share the subject, never the " \
          "sentences. Re-resolve #{quoted(shared)}."
      end

      def quoted(shared)
        listed = shared.first(SHOWN).map { |run| "\"#{run}\"" }
        extra = shared.size - listed.size
        extra.positive? ? "#{listed.join(', ')} and #{extra} more" : listed.join(', ')
      end
    end
  end
end
