# frozen_string_literal: true

require_relative '../error'
require_relative '../merge_hold'
require_relative '../merge_limits'
require_relative '../merge_review_floor'
require_relative '../post_implementation_report'

module Shaka
  # Tells a maintainer on Ask whether Auto would have merged a ready PR, so they can try
  # merge.auto_max_review_floor on real PRs before switching to auto. A hold label is named
  # too, because merge refuses it whatever the floor.
  module AutoMergePreview
    LABEL = '**Auto merge preview:**'

    module_function

    # seam is the trusted RepositoryConfig; pull is the snapshot with GitHub's size counts; verdict is the
    # checkpoint's verification verdict. Returns nil unless the repository is on Ask with a floor below the top level.
    def line(seam, github, pull, head, verdict = nil)
      floor = MergeReviewFloor.from(seam)
      return unless seam&.merge&.fetch('preference') == 'ask' && floor.holds_any?

      reasons = [label_hold(seam, pull), limits_hold(seam, pull), floor_hold(floor, github, head),
                 verdict_hold(verdict)].compact
      unless reasons.empty?
        return "#{LABEL} with `merge.preference: auto`, the agent would hand this PR back: #{reasons.join('; ')}."
      end

      "#{LABEL} this PR passes the review floor and size checks Auto applies; the agent would still " \
        'judge its risk and compatibility before merging.'
    end

    def verdict_hold(verdict)
      "the checkpoint's verdict on its verification is #{verdict}" if
        PostImplementationReport::STOPS_AGENT_MERGE.include?(verdict)
    end

    def label_hold(seam, pull)
      hold = MergeHold.from(seam)
      label = hold.label(hold.names(pull))
      "it carries the hold label `#{label}`" if label
    rescue Error
      'Shaka could not read its labels from GitHub'
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
