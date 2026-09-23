# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Seam
    # Review and merge flags for `shaka seam init`.
    module PolicyOptions
      private

      def add_policy_options(flags)
        add_review_policy_options(flags)
        flags.on('--merge-preference MODE', %w[ask auto], 'ask or auto (default: ask)') do |value|
          @options[:merge_preference] = value
        end
        flags.on('--plan PATH', 'Optional repository-relative plan path') { |value| @options[:plan] = value }
      end

      def add_review_policy_options(flags)
        flags.on('--review-policy MODE', %w[always meaningful_changes none],
                 'always, meaningful_changes, or none') { |value| @options[:review_policy] = value }
        flags.on('--ci-review-agent NAME', 'CI review job name; repeat for another job') do |value|
          (@options[:ci_review_agents] ||= []) << value
        end
        reject_retired_review_flags(flags)
      end

      def reject_retired_review_flags(flags)
        flags.on('--github-action-check NAME', 'Renamed to --ci-review-agent') do
          raise Error, '--github-action-check moved to --ci-review-agent'
        end
        flags.on('--review-check NAME', 'Renamed to --ci-review-agent') do
          raise Error, '--review-check moved to --ci-review-agent'
        end
      end
    end
  end
end
