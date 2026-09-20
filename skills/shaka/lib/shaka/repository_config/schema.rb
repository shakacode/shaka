# frozen_string_literal: true

require_relative '../error'
require_relative 'branch_schema'
require_relative 'command_schema'
require_relative 'recovery_schema'
require_relative 'review_schema'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the complete version-one repository contract.
    class Schema
      include Validation

      REQUIRED = %w[version base_branch review merge].freeze
      OPTIONAL = %w[plan branches recovery].freeze

      attr_reader :commands

      def initialize(root:, data:, available_commands: nil)
        @root = root
        @data = data
        @available_commands = available_commands
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

      def validate_header
        raise Error, 'version must be 1' unless @data['version'] == 1

        string!(@data['base_branch'], 'base_branch')
        file!(@data['plan'], 'plan') if @data.key?('plan')
      end

      def validate_optional
        BranchSchema.new(@data['branches']).validate if @data.key?('branches')
        RecoverySchema.new(@data['recovery']).validate if @data.key?('recovery')
      end

      def validate_commands
        @commands = CommandSchema.new(root: @root, available_commands: @available_commands).validate
      end

      def validate_review
        review = mapping!(@data['review'], 'review')
        ReviewSchema.retired!(review)
        optional = %w[check reviewers pace]
        keys!(review, ['required'], optional, 'review')
        ReviewSchema.new(review).validate
      end

      def validate_merge
        merge = mapping!(@data['merge'], 'merge')
        retired = %w[method release].find { |key| merge.key?(key) }
        raise Error, "merge.#{retired} is no longer configurable; see docs/settings.md" if retired

        keys!(merge, ['preference'], [], 'merge')
        enum!(merge['preference'], %w[ask auto], 'merge.preference must be ask or auto')
      end

      def reject_retired_root_keys
        retired = %w[protection trusted_actions].find { |key| @data.key?(key) }
        return unless retired

        raise Error, "#{retired} moved out of the seam; see docs/settings.md"
      end
    end
  end
end
