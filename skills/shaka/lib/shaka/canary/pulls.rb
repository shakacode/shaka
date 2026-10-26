# frozen_string_literal: true

module Shaka
  module Canary
    # Picks the pull request this run opened, the one before it, and older ones to close.
    module Pulls
      KEEP = 5

      module_function

      def newest_since(pulls, since)
        pulls.select { |pull| created(pull) >= since }.max_by { |pull| pull.fetch('createdAt') }
      end

      def previous(pulls, number)
        current = pulls.find { |pull| pull['number'] == number }
        return unless current

        older(pulls, current).max_by { |pull| pull.fetch('createdAt') }
      end

      def closable(pulls, keep:, current: nil)
        open = pulls.select { |pull| pull['state'].to_s.casecmp?('open') }
        ranked = open.sort_by { |pull| pull.fetch('createdAt') }.reverse
        ranked.drop(keep).reject { |pull| pull['number'] == current }
      end

      def older(pulls, current)
        pulls.select do |pull|
          pull['number'] != current['number'] && pull.fetch('createdAt') < current.fetch('createdAt')
        end
      end

      def created(pull) = Time.iso8601(pull.fetch('createdAt'))
    end
  end
end
