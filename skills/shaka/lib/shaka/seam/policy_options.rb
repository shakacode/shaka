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
        flags.on('--github-action-check NAME', 'GitHub Actions job Shaka reads') do |value|
          @options[:github_action_check] = value
        end
        flags.on('--review-check NAME', 'Renamed to --github-action-check') do
          raise Error, '--review-check moved to --github-action-check'
        end
      end
    end
  end
end
