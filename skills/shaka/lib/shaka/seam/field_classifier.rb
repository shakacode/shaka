# frozen_string_literal: true

module Shaka
  class Seam
    # Maps predecessor seam keys onto typed destinations without guessing policy.
    class FieldClassifier
      MOVED_TO_AGENTS = %w[
        review_gate approval_exempt changelog benchmark_labels merge_ledger follow_up_prefix
        writing_style untrusted_contributor_intake secret_redaction_patterns
        trusted_github_actor_boundary compact_terminal_structure_max_lanes merge_submission
        autonomous_merge automation_reviewers hosted_qa_gate
      ].freeze
      MOVED_TO_OPERATIONAL = %w[
        trusted_actions hosted_ci_trigger ci_change_detector ci_parity_environment
      ].freeze
      RETIRED = %w[protection commands coordination_backend].freeze
      RETAINED = %w[base_branch repo_prefix version plan branches recovery].freeze
      REVIEW_KEYS = %w[required check reviewers pace].freeze
      MERGE_RETAINED = %w[preference].freeze
      MERGE_RETIRED = %w[method release].freeze

      Result = Struct.new(:retained, :moved_to_agents, :moved_to_operational_config, :retired, :blocking,
                          :established, keyword_init: true)

      def initialize(data)
        @data = data
        @retained = []
        @moved_to_agents = []
        @moved_to_operational_config = []
        @retired = []
        @blocking = []
        @established = {}
      end

      def call
        mapping = @data
        unless mapping.is_a?(Hash) && mapping.keys.all?(String)
          @blocking << '.agents/agent-workflow.yml'
          return result
        end

        mapping.each { |key, value| classify_root(key, value) }
        require_review_and_merge
        result
      end

      private

      def classify_root(key, value)
        return retain(key, value) if RETAINED.include?(key)
        return classify_review(value) if key == 'review'
        return classify_merge(value) if key == 'merge'
        return record(@moved_to_agents, key) if MOVED_TO_AGENTS.include?(key)
        return record(@moved_to_operational_config, key) if MOVED_TO_OPERATIONAL.include?(key)

        RETIRED.include?(key) ? record(@retired, key) : @blocking << key
      end

      def retain(key, value)
        if %w[branches recovery].include?(key) && !value.is_a?(Hash)
          @blocking << key
          return
        end

        @retained << key
        @established[key] = value if %w[base_branch repo_prefix version plan branches recovery].include?(key)
      end

      def classify_review(value)
        return @blocking << 'review' unless value.is_a?(Hash) && value.keys.all?(String)

        value.each do |key, nested|
          unless REVIEW_KEYS.include?(key)
            @blocking << "review.#{key}"
            next
          end

          @retained << "review.#{key}"
          store_review(key, nested)
        end
      end

      def classify_merge(value)
        return @blocking << 'merge' unless value.is_a?(Hash) && value.keys.all?(String)

        value.each do |key, nested|
          next store_merge(key, nested) if MERGE_RETAINED.include?(key)
          next record(@retired, "merge.#{key}") if MERGE_RETIRED.include?(key)

          @blocking << "merge.#{key}"
        end
      end

      def store_review(key, value)
        @established['review'] ||= {}
        @established['review'][key] = value
      end

      def store_merge(key, value)
        record(@retained, "merge.#{key}")
        @established['merge'] ||= {}
        @established['merge'][key] = value
      end

      def require_review_and_merge
        required = @established.dig('review', 'required')
        @blocking << 'review.required' unless required
        @blocking << 'review.check' if required && required != 'none' && !@established.dig('review', 'check')
        @blocking << 'merge.preference' unless @established.dig('merge', 'preference')
      end

      def record(list, key)
        list << key
      end

      def result
        Result.new(retained: @retained.uniq, moved_to_agents: @moved_to_agents.uniq,
                   moved_to_operational_config: @moved_to_operational_config.uniq, retired: @retired.uniq,
                   blocking: @blocking.uniq, established: @established)
      end
    end
  end
end
