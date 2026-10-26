# frozen_string_literal: true

require_relative '../claim/names'

module Shaka
  module Canary
    # Picks the pull request this run opened, the one before it, and older ones to close.
    module Pulls
      KEEP = 5
      AD_HOC = Regexp.escape(Claim::Names::AD_HOC)
      BRANCH = %r{\Ashaka-canary/(?:#{AD_HOC}-)?run-\d+-\d+\z}

      module_function

      def canaries(pulls)
        pulls.select { |pull| pull['isCrossRepository'] == false && BRANCH.match?(pull['headRefName'].to_s) }
      end

      def for_run(pulls, branch)
        raise ArgumentError, 'missing or invalid canary run branch' unless BRANCH.match?(branch.to_s)

        canaries(pulls).select { |pull| pull['headRefName'] == branch }
      end

      def from_api(pull)
        head = pull.dig('head', 'repo', 'id')
        { 'number' => pull.fetch('number'), 'state' => pull.fetch('state'),
          'createdAt' => pull.fetch('created_at'), 'headRefName' => pull.dig('head', 'ref'),
          'isCrossRepository' => head.nil? || head != pull.dig('base', 'repo', 'id') }
      end

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
