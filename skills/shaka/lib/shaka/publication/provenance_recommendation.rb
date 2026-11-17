# frozen_string_literal: true

require_relative 'provenance_history'

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
    # goes on the history entry that records a change.
    Result = Data.define(:spec, :kept, :reason)

    module_function

    def resolve(pull, spec)
      supplied = SETTINGS.map { |setting| spec["recommended_#{setting}"] }
      recorded = recorded(pull)
      # The Task line validated the supplied provenance before this runs.
      return Result.new(spec:, kept: nil, reason: nil) unless recorded

      route = recorded.zip(supplied).map { |old, new| keep?(old, new, spec) ? old : new }
      Result.new(spec: with_route(spec, route), kept: (route.join(' / ') unless route == supplied),
                 reason: (spec[REASON] unless route == recorded))
    end

    def recorded(pull) = ProvenanceHistory.last_entry(pull)&.fetch('recommended')&.split(' / ', 2)

    def with_route(spec, route) = spec.merge(SETTINGS.zip(route).to_h { |name, value| ["recommended_#{name}", value] })

    def note(route)
      "Kept the recorded recommendation, showing #{route}. To record a new plan, supply provenance " \
        "#{REASON} and publish again."
    end

    def keep?(old, new, spec) = new == UNKNOWN || (old != UNKNOWN && !spec.key?(REASON))

    private_class_method :recorded, :with_route, :keep?
  end
end
