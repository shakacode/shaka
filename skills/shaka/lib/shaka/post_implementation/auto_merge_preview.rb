# frozen_string_literal: true

require_relative '../error'
require_relative '../merge_limits'
require_relative '../merge_review_floor'

module Shaka
  # Tells a maintainer on Ask whether Auto would have merged a ready PR, so they can try
  # merge.auto_max_review_floor on real PRs before switching to auto.
  module AutoMergePreview
    LABEL = '**Auto merge preview:**'

    module_function

    # seam is the trusted RepositoryConfig; pull is the snapshot with GitHub's size counts.
    # Returns nil unless the repository is on Ask with a floor below the top level.
    def line(seam, github, pull, head)
      floor = MergeReviewFloor.from(seam)
      return unless seam&.merge&.fetch('preference') == 'ask' && floor.holds_any?

      reasons = [limits_hold(seam, pull), floor_hold(floor, github, head)].compact
      unless reasons.empty?
        return "#{LABEL} with `merge.preference: auto`, the agent would hand this PR back: #{reasons.join('; ')}."
      end

      "#{LABEL} this PR passes the review floor and size checks Auto applies; the agent would still " \
        'judge its risk and compatibility before merging.'
    end

    def limits_hold(seam, pull)
      exceeded = MergeLimits.new(seam.merge.fetch('limits')).exceeded(pull)
      "it is past `merge.limits` (#{exceeded.join(', ')})" unless exceeded.empty?
    rescue Error
      'Shaka could not read its size from GitHub'
    end

    def floor_hold(floor, github, head)
      floor.hold(floor.paths(github, head))
    rescue Error
      'Shaka could not read its changed files from GitHub'
    end
  end
end
