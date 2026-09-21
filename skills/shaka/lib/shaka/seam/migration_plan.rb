# frozen_string_literal: true

require 'open3'
require 'shellwords'
require_relative '../repository_config'
require_relative 'field_classifier'
require_relative 'migration_policy'

module Shaka
  class Seam
    # Command inventory, collisions, and leftover adapters for a migrate report.
    module MigrationCommands
      private

      def command_report
        {
          'commands' => command_inventory,
          'command_collisions' => command_collisions,
          'adapters_eligible_for_removal' => adapters_eligible_for_removal
        }
      end

      def command_inventory
        RepositoryConfig::CommandPaths::ALL.to_h do |name, path|
          [name, { 'path' => path, 'present_at_from_ref' => command_present?(path) }]
        end
      end

      def command_present?(path)
        _out, status = Open3.capture2e('git', '-C', root, 'cat-file', '-e', "#{@sha}:#{path}")
        status.success?
      end

      def command_collisions
        mapping = command_mapping
        return [] unless mapping

        RepositoryConfig::CommandPaths::ALL.keys.filter_map { |role| collision_for(role, mapping) }
      end

      def command_mapping
        @data['commands'] if @data.is_a?(Hash) && @data['commands'].is_a?(Hash)
      end

      def collision_for(role, mapping)
        expected = RepositoryConfig::CommandPaths::ALL.fetch(role)
        actual = mapping[role]
        return if actual.nil? || actual == expected

        { 'role' => role, 'mapped_path' => actual, 'temporary_behavior' => collision_behavior(role, mapping) }
      end

      def collision_behavior(role, mapping)
        return setup_collision_behavior(mapping.fetch(role)) if role == 'setup'
        return optional_collision_behavior(role, mapping.fetch(role)) if optional_role?(role)

        targets = [mapping['validate'], mapping['test']].compact.uniq.join(' and ')
        'Until the new seam is trusted, use the stricter superset: both .agents/bin/validate and ' \
          ".agents/bin/test must execute #{targets}"
      end

      def optional_role?(role)
        RepositoryConfig::CommandPaths::OPTIONAL.key?(role)
      end

      def setup_collision_behavior(actual)
        "Keep #{actual} reachable from .agents/bin/setup until the new seam is trusted"
      end

      def optional_collision_behavior(role, actual)
        expected = RepositoryConfig::CommandPaths::OPTIONAL.fetch(role)
        "Keep #{actual} reachable from #{expected} until the new seam is trusted"
      end

      def require_optional_entry_points(classified)
        mapping = command_mapping
        return unless mapping

        RepositoryConfig::CommandPaths::OPTIONAL.each do |role, path|
          next unless mapping.key?(role)
          next if command_present?(path) || File.file?(File.join(root, path))

          classified.blocking << path
        end
      end

      def adapters_eligible_for_removal
        mapping = command_mapping
        return [] unless mapping

        RepositoryConfig::CommandPaths::ALL.filter_map do |role, expected|
          actual = mapping[role]
          actual if actual.is_a?(String) && actual != expected
        end
      end
    end

    # Deterministic migrate report from a predecessor YAML document.
    module MigrationPlan
      include MigrationPolicy
      include MigrationCommands

      private

      def build_report
        classified = FieldClassifier.new(@data).call
        overlay_explicit_policy(classified)
        require_optional_entry_points(classified)
        report_body(classified)
      end

      def report_body(classified)
        {
          'mode' => @options[:apply] ? 'apply' : 'plan',
          'from_ref' => @sha,
          'retained' => classified.retained,
          'moved_to_agents' => classified.moved_to_agents,
          'moved_to_operational_config' => classified.moved_to_operational_config,
          'retired' => classified.retired,
          'blocking' => classified.blocking,
          'established' => classified.established
        }.merge(command_report, validation_report)
      end

      def validation_report
        {
          'validation' => validation_notes,
          'rollback' => rollback_recipe
        }
      end

      def rollback_recipe
        restore = "git -C #{Shellwords.escape(root)} checkout #{@sha} -- #{RepositoryConfig::PATH}"
        return "#{restore} .agents/shaka.md" if command_present?('.agents/shaka.md')

        "#{restore} && rm -f #{Shellwords.escape(File.join(root, '.agents/shaka.md'))}"
      end

      def validation_notes
        {
          'previous_trusted_ref' =>
            "required before merge with the previous Shaka installation: shaka seam check --root #{root} --ref #{@sha}",
          'candidate_local' =>
            "target Shaka candidate check (grants no authority): shaka seam check --root #{root} --local"
        }
      end
    end
  end
end
