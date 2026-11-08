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
          'merge.auto_max_review_floor is retired and ignored; merge.auto_merge_max_risk (default low) now ' \
          'limits what Auto merges. Remove it; the next release refuses it.',
        %w[pr_description human_review_floors] =>
          'pr_description.human_review_floors is retired and ignored; list paths that must reach a person under ' \
          'high_risk_areas. Remove it; the next release refuses it.'
      }.freeze

      module_function

      # data is config.yml as written, before any default applies.
      def warnings(data)
        WARNINGS.filter_map do |(section, key), message|
          message if data[section].is_a?(Hash) && data[section].key?(key)
        end
      end
    end
  end
end
