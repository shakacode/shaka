# frozen_string_literal: true

module Shaka
  class RepositoryConfig
    # Settings the risk rating replaced. For one release a repository that still sets them loads with a warning
    # and the values are ignored; the next release refuses them.
    module RetiredSettings
      MERGE = 'auto_max_review_floor'
      PR_DESCRIPTION = 'human_review_floors'
      WARNINGS = {
        %w[merge auto_max_review_floor] =>
          'merge.auto_max_review_floor is retired; merge.auto_merge_max_risk (default low) now limits what ' \
          'Auto merges. Below 5 it holds every agent merge until removed; move the paths its floors held into ' \
          'high_risk_areas or medium_risk_areas, then remove it. The next release refuses it.',
        %w[pr_description human_review_floors] =>
          'pr_description.human_review_floors is retired and ignored; list paths that must reach a person under ' \
          'high_risk_areas. Remove it; the next release refuses it.'
      }.freeze

      module_function

      # The retired merge floor when it held files from Auto, that is any value but the top level 5, which held
      # nothing. Until the repository moves those paths into risk areas and removes it, merge holds Auto.
      def held_floor(data)
        merge = data['merge']
        return unless merge.is_a?(Hash) && merge.key?(MERGE) && merge[MERGE] != 5

        merge[MERGE].inspect
      end

      # data is config.yml as written, before any default applies.
      def warnings(data)
        WARNINGS.filter_map do |(section, key), message|
          message if data[section].is_a?(Hash) && data[section].key?(key)
        end
      end
    end
  end
end
