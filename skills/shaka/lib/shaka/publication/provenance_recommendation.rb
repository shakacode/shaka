# frozen_string_literal: true

require_relative 'provenance_history'

module Shaka
  # Keeps the plan-time recommendation across a PR's publications, since each publication
  # re-enters it and later ones drifted to the active model or UNKNOWN (issue #1187). A new
  # recommendation replaces it only with a stated reason, or when the recorded one is UNKNOWN.
  module ProvenanceRecommendation
    UNKNOWN = 'UNKNOWN'
    REASON = 'recommendation_change_reason'

    # spec renders; kept names the recorded route that overrode the supplied one; reason goes
    # on the history entry that records a replacement.
    Result = Data.define(:spec, :kept, :reason)

    module_function

    def resolve(pull, spec)
      recorded = ProvenanceHistory.last_entry(pull)&.fetch('recommended')&.split(' / ', 2)
      supplied = [spec['recommended_model'], spec['recommended_effort']]
      return Result.new(spec:, kept: nil, reason: nil) if recorded.nil? || recorded == supplied
      return Result.new(spec:, kept: nil, reason: spec[REASON]) if replaceable?(recorded, supplied, spec)

      kept = { 'recommended_model' => recorded.first, 'recommended_effort' => recorded.last }
      Result.new(spec: spec.merge(kept), kept: recorded.join(' / '), reason: nil)
    end

    def note(route)
      "Kept the recorded recommendation #{route}. To record a new plan, supply provenance " \
        "#{REASON} and publish again."
    end

    def replaceable?(recorded, supplied, spec)
      return false if supplied.include?(UNKNOWN)

      recorded.include?(UNKNOWN) || spec.key?(REASON)
    end

    private_class_method :replaceable?
  end
end
