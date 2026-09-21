# frozen_string_literal: true

require 'open3'
require_relative '../repository_config'
require_relative 'field_classifier'

module Shaka
  class Seam
    # Deterministic migrate report from a predecessor YAML document.
    module MigrationPlan
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
          'rollback' => "Restore predecessor files with git checkout #{@sha} -- #{RepositoryConfig::PATH} .agents/bin"
        }
      end

      def overlay_explicit_policy(classified)
        overlay_review(classified) if @options[:review_policy]
        overlay_merge(classified) if @options[:merge_preference]
        classified.blocking.delete('review.required') if classified.established.dig('review', 'required')
        classified.blocking.delete('merge.preference') if classified.established.dig('merge', 'preference')
      end

      def overlay_review(classified)
        none = @options[:review_policy] == 'none'
        raise Error, '--review-check must be omitted when review policy is none' if none && @options.key?(:review_check)
        raise Error, '--review-check is required' if !none && !@options[:review_check]

        classified.established['review'] = { 'required' => @options[:review_policy] }
        classified.established['review']['check'] = @options[:review_check] if @options[:review_check]
      end

      def overlay_merge(classified)
        classified.established['merge'] = { 'preference' => @options[:merge_preference] }
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
