# frozen_string_literal: true

require_relative '../branch_name'
require_relative '../error'
require_relative '../repo_prefix'
require_relative 'branch_schema'
require_relative 'command_schema'
require_relative 'merge_schema'
require_relative 'wip_schema'
require_relative 'review_schema'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the complete version-one repository contract.
    class Schema
      include Validation

      REQUIRED = %w[version review merge].freeze
      OPTIONAL = %w[base_branch branches wip repo_prefix].freeze

      attr_reader :commands

      def initialize(root:, data:, available_commands: nil, candidate_commands: true)
        @root = root
        @data = data
        @available_commands = available_commands
        @candidate_commands = candidate_commands
      end

      def validate
        mapping!(@data, PATH)
        reject_retired_root_keys
        keys!(@data, REQUIRED, OPTIONAL, PATH)
        validate_header
        validate_commands
        validate_review
        validate_merge
        validate_optional
      end

      private

      # base_branch is validated only when present. An absent key resolves to the
      # repository's default branch at runtime, which is valid by construction.
      def validate_header
        raise Error, 'version must be 1' unless @data['version'] == 1

        BranchName.explicit!(@data['base_branch'], label: 'base_branch', root: @root) if @data.key?('base_branch')
      end

      def validate_optional
        BranchSchema.new(@data['branches']).validate if @data.key?('branches')
        WipSchema.new(@data['wip']).validate if @data.key?('wip')
        RepoPrefix.validate!(@data['repo_prefix']) if @data.key?('repo_prefix')
      end

      def validate_commands
        @commands = CommandSchema.new(root: @root, available_commands: @available_commands,
                                      candidate_commands: @candidate_commands).validate
      end

      def validate_review
        review = mapping!(@data['review'], 'review')
        ReviewSchema.retired!(review)
        ReviewSchema.renamed!(review)
        optional = [ReviewSchema::CI_REVIEW_JOBS, ReviewSchema::LOCAL_REVIEW_AGENTS, 'ci_review_wait']
        keys!(review, ['required'], optional, 'review')
        ReviewSchema.new(review).validate
      end

      def validate_merge
        MergeSchema.new(@data['merge']).validate
      end

      def reject_retired_root_keys
        if @data.key?('recovery')
          raise Error, 'recovery moved to wip.include_locations; migrate the location setting before use'
        end

        retired = %w[protection trusted_actions plan].find { |key| @data.key?(key) }
        return unless retired

        raise Error, "#{retired} moved out of the seam; see skills/shaka/references/migration.md"
      end
    end
  end
end
