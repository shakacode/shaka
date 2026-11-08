# frozen_string_literal: true

require_relative '../error'
require_relative '../merge_hold'
require_relative '../merge_limits'
require_relative '../merge_risk_gate'
require_relative '../post_implementation_report'

module Shaka
  # Tells a maintainer on Ask whether Auto would have merged a ready PR, so they can try
  # merge.auto_merge_max_risk on real PRs before switching to auto. A hold label is named too, because merge
  # refuses it whatever the rating.
  module AutoMergePreview
    LABEL = '**Auto merge preview:**'

    module_function

    # seam is the trusted RepositoryConfig; pull is the snapshot with GitHub's size counts; checkpoint holds the
    # checkpoint's :verdict on verification and its risk :assessment. Returns nil unless the repository is on Ask.
    def line(seam, pull, checkpoint = {})
      return unless seam&.merge&.fetch('preference') == 'ask'

      reasons = [label_hold(seam, pull), limits_hold(seam, pull), gate_hold(seam, checkpoint[:assessment]),
                 verdict_hold(checkpoint[:verdict])].compact
      return passing if reasons.empty?

      "#{LABEL} with `merge.preference: auto`, the agent would hand this PR back: #{reasons.join('; ')}."
    end

    def passing
      "#{LABEL} this PR passes the risk rating and size checks Auto applies; " \
        'the agent would still judge its risk and compatibility before merging.'
    end

    # The rating decides against merge.auto_merge_max_risk, as MergeRiskGate does.
    def gate_hold(seam, assessment)
      retired = MergeRiskGate.retired(seam)
      return retired if retired
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
  end
end
