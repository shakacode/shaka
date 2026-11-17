# frozen_string_literal: true

require_relative 'provenance_history'

module Shaka
  # Keeps the plan-time recommendation across a PR's publications, since each publication
  # re-enters it and later ones drifted to the active model or UNKNOWN (issue #1187). Model
  # and effort each keep their recorded value; only a recorded UNKNOWN, in any case, takes a new one.
  module ProvenanceRecommendation
    UNKNOWN = 'UNKNOWN'
    SETTINGS = %w[model effort].freeze

    # spec renders; kept names the recorded route when it differs from the supplied one.
    Result = Data.define(:spec, :kept)

    module_function

    def resolve(pull, spec)
      recorded = recorded(pull)
      # The Task line validated the supplied provenance before this runs.
      return Result.new(spec:, kept: nil) unless recorded

      supplied = SETTINGS.map { |setting| spec["recommended_#{setting}"] }
      route = recorded.zip(supplied).map { |old, new| old.casecmp?(UNKNOWN) ? new : old }
      Result.new(spec: spec.merge('recommended_model' => route.first, 'recommended_effort' => route.last),
                 kept: (route.join(' / ') unless route == supplied))
    end

    def recorded(pull) = ProvenanceHistory.entries(pull).last&.fetch('recommended')&.split(' / ', 2)

    def note(route)
      "Kept the plan-time recommendation #{route}. Describe a changed plan in task_history instead."
    end

    private_class_method :recorded
  end
end
