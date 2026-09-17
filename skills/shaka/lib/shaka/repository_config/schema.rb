# frozen_string_literal: true

require 'pathname'
require_relative '../error'

module Shaka
  class RepositoryConfig
    # Validates the complete version-one repository contract.
    class Schema
      REQUIRED = %w[version base_branch commands review merge protection].freeze
      OPTIONAL = %w[plan trusted_actions].freeze

      def initialize(root:, data:)
        @root = root
        @data = data
      end

      def validate
        mapping!(@data, PATH)
        keys!(@data, REQUIRED, OPTIONAL, PATH)
        equal!(@data['version'], 1, 'version must be 1')
        string!(@data['base_branch'], 'base_branch')
        file!(@data['plan'], 'plan') if @data.key?('plan')
        validate_commands
        validate_review
        validate_merge
        validate_protection
        validate_trusted_actions
      end

      private

      def validate_commands
        commands = mapping!(@data['commands'], 'commands')
        names = %w[setup validate test]
        keys!(commands, names, [], 'commands')
        names.each { |name| executable!(commands[name], "commands.#{name}") }
      end

      def validate_review
        review = mapping!(@data['review'], 'review')
        keys!(review, ['required'], ['check'], 'review')
        enum!(review['required'], %w[always meaningful_changes none],
              'review.required must be always, meaningful_changes, or none')
        if review['required'] == 'none'
          raise Error, 'review.check must be omitted when review.required is none' if review.key?('check')
        else
          string!(review['check'], 'review.check')
        end
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

      def keys!(mapping, required, optional, label)
        unknown = mapping.keys - required - optional
        missing = required - mapping.keys
        raise Error, "unknown key: #{unknown.first}" unless unknown.empty?
        raise Error, "missing #{label} key: #{missing.first}" unless missing.empty?
      end

      def mapping!(value, label)
        raise Error, "#{label} must be a mapping" unless value.is_a?(Hash) && value.keys.all?(String)

        value
      end

      def string!(value, label)
        raise Error, "#{label} must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?

        value
      end

      def strings!(value, label)
        valid = value.is_a?(Array) && value.all? { |item| item.is_a?(String) && !item.strip.empty? }
        raise Error, "#{label} must be a list of non-empty strings" unless valid

        value
      end

      def enum!(value, allowed, message)
        raise Error, message unless allowed.include?(value)
      end

      def equal!(actual, expected, message)
        raise Error, message unless actual == expected
      end

      def file!(value, label)
        path = repository_path(value, label)
        raise Error, "#{label} does not exist: #{value}" unless File.file?(path)

        real_path = File.realpath(path)
        raise Error, "#{label} must resolve inside the repository" unless real_path.start_with?("#{@root}/")

        path
      end

      def executable!(value, label)
        path = file!(value, label)
        raise Error, "#{label} is not executable: #{value}" unless File.executable?(path)
      end

      def repository_path(value, label)
        relative = string!(value, label)
        expanded = File.expand_path(relative, @root)
        inside = !Pathname.new(relative).absolute? && expanded.start_with?("#{@root}/")
        raise Error, "#{label} must stay inside the repository" unless inside

        expanded
      end
    end
  end
end
