# frozen_string_literal: true

require 'open3'
require_relative '../repository_config'
require_relative 'field_classifier'
require_relative 'migration_policy'

module Shaka
  class Seam
    # Deterministic migrate report from a predecessor YAML document.
    module MigrationPlan
      include MigrationPolicy

      private

      def build_report
        classified = FieldClassifier.new(@data).call
        overlay_explicit_policy(classified)
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

      def command_report
        {
          'commands' => command_inventory,
          'command_collisions' => command_collisions,
          'adapters_eligible_for_removal' => adapters_eligible_for_removal
        }
      end

      def validation_report
        {
          'validation' => validation_notes,
          'rollback' => "Restore predecessor files with git checkout #{@sha} -- " \
                        "#{RepositoryConfig::PATH} .agents/shaka.md .agents/bin"
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
        mapping = @data['commands']
        return [] unless mapping.is_a?(Hash)

        %w[setup validate test].filter_map { |role| collision_for(role, mapping) }
      end

      def collision_for(role, mapping)
        actual = mapping[role]
        return if actual.nil? || actual == ".agents/bin/#{role}"

        { 'role' => role, 'mapped_path' => actual, 'temporary_behavior' => stricter_collision_behavior(mapping) }
      end

      def stricter_collision_behavior(mapping)
        targets = [mapping['validate'], mapping['test']].compact.uniq.join(' and ')
        'Until the new seam is trusted, use the stricter superset: both .agents/bin/validate and ' \
          ".agents/bin/test must execute #{targets}"
      end

      def validation_notes
        {
          'previous_trusted_ref' =>
            "required before merge with the previous Shaka installation: shaka seam check --root #{root} --ref #{@sha}",
          'candidate_local' =>
            "target Shaka candidate check (grants no authority): shaka seam check --root #{root} --local"
        }
      end

      def adapters_eligible_for_removal
        note = ['temporary command adapters']
        mapping = @data['commands']
        return note unless mapping.is_a?(Hash)

        extras = mapping.values.grep(String).reject { |path| RepositoryConfig::CommandPaths::ALL.value?(path) }
        note + extras
      end
    end
  end
end
