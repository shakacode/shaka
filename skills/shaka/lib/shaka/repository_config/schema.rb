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

      REQUIRED = %w[version base_branch review merge protection].freeze
      OPTIONAL = %w[plan trusted_actions branches recovery].freeze

      attr_reader :commands

      def initialize(root:, data:, available_commands: nil)
        @root = root
        @data = data
        @available_commands = available_commands
      end

      def validate
        mapping!(@data, PATH)
        keys!(@data, REQUIRED, OPTIONAL, PATH)
        validate_header
        validate_commands
        validate_review
        validate_merge
        validate_protection
        validate_optional
      end

      private

      def validate_header
        equal!(@data['version'], 1, 'version must be 1')
        string!(@data['base_branch'], 'base_branch')
        file!(@data['plan'], 'plan') if @data.key?('plan')
      end

      def validate_optional
        validate_trusted_actions
        BranchSchema.new(@data['branches']).validate if @data.key?('branches')
        RecoverySchema.new(@data['recovery']).validate if @data.key?('recovery')
      end

      def validate_commands
        @commands = CommandSchema.new(root: @root, available_commands: @available_commands).validate
      end

      def validate_review
        review = mapping!(@data['review'], 'review')
        ReviewSchema.retired!(review)
        optional = %w[check reviewers]
        keys!(review, ['required'], optional, 'review')
        ReviewSchema.new(review).validate
      end

      def validate_merge
        merge = mapping!(@data['merge'], 'merge')
        keys!(merge, %w[preference method release], [], 'merge')
        enum!(merge['preference'], %w[ask auto], 'merge.preference must be ask or auto')
        equal!(merge['method'], 'squash', 'merge.method must be squash')
        equal!(merge['release'], 'explicit_approval', 'merge.release must be explicit_approval')
      end

      def validate_protection
        protection = mapping!(@data['protection'], 'protection')
        fields = %w[required_checks direct_push force_push branch_deletion]
        keys!(protection, fields, [], 'protection')
        checks = strings!(protection['required_checks'], 'protection.required_checks')
        raise Error, 'protection.required_checks must not be empty' if checks.empty?

        fields.drop(1).each { |key| equal!(protection[key], false, "protection.#{key} must be false") }
      end

      def validate_trusted_actions
        return unless @data.key?('trusted_actions')

        actions = strings!(@data['trusted_actions'], 'trusted_actions')
        raise Error, 'trusted_actions must not be empty' if actions.empty?
      end

      def strings!(value, label)
        valid = value.is_a?(Array) && value.all? { |item| item.is_a?(String) && !item.strip.empty? }
        raise Error, "#{label} must be a list of non-empty strings" unless valid

        value
      end

      def equal!(actual, expected, message)
        raise Error, message unless actual == expected
      end
    end
  end
end
