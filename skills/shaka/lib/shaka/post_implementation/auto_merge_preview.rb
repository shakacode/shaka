# frozen_string_literal: true

require_relative '../error'
require_relative '../merge_hold'
require_relative '../merge_limits'
require_relative '../merge_review_floor'
require_relative '../merge_risk_gate'
require_relative '../post_implementation_report'

module Shaka
  # Tells a maintainer on Ask whether Auto would have merged a ready PR, so they can try
  # merge.auto_max_review_floor or merge.auto_merge_max_risk on real PRs before switching to auto. A hold
  # label is named too, because merge refuses it whatever the floor or rating.
  module AutoMergePreview
    LABEL = '**Auto merge preview:**'

    module_function

    # seam is the trusted RepositoryConfig; pull is the snapshot with GitHub's size counts; checkpoint holds the
    # checkpoint's :verdict on verification and its risk :assessment. Returns nil unless the repository is on Ask
    # with merge.auto_merge_max_risk set, a floor below the top level, or a hold label on the PR.
    def line(seam, github, pull, head, checkpoint = {})
      return unless seam&.merge&.fetch('preference') == 'ask'

      label = label_hold(seam, pull)
      return unless label || gated?(seam)

      reasons = [label, limits_hold(seam, pull), gate_hold(seam, github, head, checkpoint[:assessment]),
                 verdict_hold(checkpoint[:verdict])].compact
      return passing(seam) if reasons.empty?

      "#{LABEL} with `merge.preference: auto`, the agent would hand this PR back: #{reasons.join('; ')}."
    end

    def passing(seam)
      "#{LABEL} this PR passes the #{rated?(seam) ? 'risk rating' : 'review floor'} and size checks Auto applies; " \
        'the agent would still judge its risk and compatibility before merging.'
    end

    def rated?(seam) = !MergeRiskGate.max_risk(seam).nil?

    def gated?(seam) = rated?(seam) || MergeReviewFloor.from(seam).holds_any?

    # Under merge.auto_merge_max_risk the rating decides, as MergeRiskGate does; otherwise the review floors.
    def gate_hold(seam, github, head, assessment)
      return floor_hold(MergeReviewFloor.from(seam), github, head) unless rated?(seam)
      return 'the checkpoint has no risk rating' unless assessment

      MergeRiskGate.reason(assessment, MergeRiskGate.max_risk(seam))
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
      return unless floor.holds_any?

      floor.hold(floor.paths(github, head))
    rescue Error
      'Shaka could not read its changed files from GitHub'
    end
  end
end
