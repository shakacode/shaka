# frozen_string_literal: true

require_relative 'provenance_history'
require_relative 'provenance_replans'

module Shaka
  # Keeps the plan-time recommendation across a PR's publications, since each publication
  # re-enters it and later ones drifted to the active model or UNKNOWN (issue #1187). Each of
  # model and effort keeps its recorded value unless a stated reason replaces it; a recorded
  # UNKNOWN takes a concrete value, and a concrete value never becomes UNKNOWN.
  module ProvenanceRecommendation
    UNKNOWN = 'UNKNOWN'
    REASON = 'recommendation_change_reason'
    SETTINGS = %w[model effort].freeze

    # spec renders; kept names the route shown when it differs from the supplied one; reason
    # explains a recorded change.
    Result = Data.define(:spec, :kept, :reason)

    module_function

    def resolve(pull, spec)
      supplied = SETTINGS.map { |setting| spec["recommended_#{setting}"] }
      entries = ProvenanceHistory.entries(pull)
      # The Task line validated the supplied provenance before this runs.
      return Result.new(spec:, kept: nil, reason: nil) if entries.empty?

      recorded = entries.last.fetch('recommended').split(' / ', 2)
      reason = fresh_reason(pull, spec)
      route = recorded.zip(supplied).map { |old, new| keep?(old, new, reason) ? old : new }
      result(spec, route, supplied:, reason: (reason unless route == recorded))
    end

    def result(spec, route, supplied:, reason:)
      Result.new(spec: with_route(spec, route), kept: (route.join(' / ') unless route == supplied), reason:)
    end

    # A reused content file resends the last replan's reason, which explains no new change.
    def fresh_reason(pull, spec)
      reason = spec[REASON]
      reason unless reason == ProvenanceReplans.recorded(pull).last&.fetch('reason')
    end

    def with_route(spec, route) = spec.merge(SETTINGS.zip(route).to_h { |name, value| ["recommended_#{name}", value] })

    def note(route)
      "Kept the recorded recommendation, showing #{route}. To record a new plan, supply a new " \
        "provenance #{REASON} and publish again."
    end

    def keep?(old, new, reason) = new == UNKNOWN || (old != UNKNOWN && reason.nil?)

    private_class_method :result, :fresh_reason, :with_route, :keep?
  end
end
