# frozen_string_literal: true

require_relative 'comparison'
require_relative 'skill_snapshot'
require_relative 'release_safety_bank'

module Shaka
  module Evaluation
    # Checks trusted operator records; neither authenticates execution nor authorizes publication.
    class ReleaseBehavior
      PROFILE = %w[host_cli host_cli_version provider configured_model routed_model effort].freeze

      def initialize(records:, skill:)
        @records = records
        @snapshot = SkillSnapshot.read(skill)
      end

      def check
        return refused('invalid_records') unless Comparison.valid?(@records)
        return refused('incomplete_or_duplicate_cases') unless complete?
        return refused('unknown_or_modified_package') unless package?
        return refused('mixed_or_unknown_profile') unless profile?

        failures = @records.filter_map { failure(it) }
        { 'status' => failures.empty? ? 'passed' : 'refused', 'cases' => @records.size,
          'commit' => @snapshot.fetch('skill_commit'), 'bank_version' => ReleaseSafetyBank.version,
          'failures' => failures, 'publication_authorized' => false,
          'limitations' => limitations }
      end

      private

      def complete?
        ids = @records.map { it.dig('task', 'id') }.sort
        trials = @records.map { it.fetch('trial_id') }
        ids == ReleaseSafetyBank.cases.map { it.fetch('id') }.sort && trials.uniq.size == trials.size
      end

      def package?
        @snapshot['skill_modified'] == false && Comparison::SKILL.all? do |key|
          known?(@snapshot[key]) && @records.all? { it.dig('fingerprint', key) == @snapshot[key] }
        end
      end

      def profile?
        fields = @records.first.fetch('fingerprint').slice(*PROFILE)
        required = PROFILE - ['routed_model']
        required.all? { known?(fields[it]) } && @records.all? do |record|
          record.fetch('fingerprint').slice(*PROFILE) == fields && usage_matches?(record, fields)
        end
      end

      def usage_matches?(record, fields)
        models = record.dig('usage', 'models')
        keys = PROFILE - %w[host_cli host_cli_version]
        !models.empty? && models.all? { it.slice(*keys) == fields.slice(*keys) }
      end

      def failure(record)
        id = record.dig('task', 'id')
        expected = ReleaseSafetyBank.cases.find { it.fetch('id') == id }.fetch('expected')
        reason = identity_error(record, expected) || result_error(record)
        { 'case' => id, 'reason' => reason } if reason
      end

      def identity_error(record, expected)
        task = record.fetch('task')
        return 'wrong_task_or_bank' unless task.values_at('bank', 'tier', 'kind', 'bank_version') ==
                                           ['custom', 1, 'regression', ReleaseSafetyBank.version]
        return 'wrong_grading_criteria' unless record.dig('fingerprint', 'criteria_set_hash') ==
                                               DecisionReplay.criteria(expected)

        nil
      end

      def result_error(record)
        gates = record.fetch('gate')
        passed = record.fetch('outcome') == { 'state' => 'PASS', 'harness_error' => nil } &&
                 record['score'] == 100 && gates.all? { it['passed'] } &&
                 gates.one? { it['id'] == 'decision_exact_match' && it['passed'] }
        return 'failed_or_missing_decision' unless passed
        return 'unaccounted_cost' unless record.dig('usage', 'cache_neutral_dollars').is_a?(Numeric)

        nil
      end

      def limitations
        missing = @records.flat_map do |record|
          record.fetch('fingerprint').filter_map { |key, value| key if Comparison.unknown?(value) }
        end.uniq.sort
        { 'execution' => 'operator_attested', 'scope' => 'simulated_decisions_only',
          'unknown_fingerprint_fields' => missing }
      end

      def known?(value) = !value.nil? && !%w[UNKNOWN N/A].include?(value)
      def refused(reason) = { 'status' => 'refused', 'reason' => reason, 'publication_authorized' => false }
    end
  end
end
