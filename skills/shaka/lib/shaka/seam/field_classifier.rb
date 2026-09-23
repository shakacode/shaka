# frozen_string_literal: true

require_relative '../repository_config/review_schema'

module Shaka
  class Seam
    # Review-key half of seam classification, including renamed keys and collisions.
    module ReviewFields
      REVIEW_KEYS = (%w[required pace] + RepositoryConfig::ReviewSchema::RENAMED.values).uniq.freeze

      private

      def classify_review(value)
        return @blocking << 'review' unless value.is_a?(Hash) && value.keys.all?(String)

        value.each { |key, nested| classify_review_entry(key, nested) }
      end

      def classify_review_entry(source, nested)
        key = RepositoryConfig::ReviewSchema::RENAMED.fetch(source, source)
        return @blocking << "review.#{source}" unless REVIEW_KEYS.include?(key)
        return @blocking << collision(source, key) if @established.fetch('review', {}).key?(key)
        return @blocking << ci_value_block(source) if unacceptable_ci_value?(source, nested)

        @retained << "review.#{key}"
        store_review(source, key, job_list(source, nested))
      end

      def collision(source, key)
        names = [source, @review_sources.fetch(key)]
        legacy = names.find { |name| name != key } || source
        "review.#{legacy} (collides with review.#{key})"
      end

      # The none-policy cleanup removes the bare field name. A bad value needs a message that stays.
      def ci_value_block(source)
        agents = RepositoryConfig::ReviewSchema::CI_REVIEW_JOBS
        return "review.#{agents} must be a list of CI job names" if source == agents

        "review.#{source}"
      end

      # A retired check is one job name. The current key is a list. Anything else blocks.
      def unacceptable_ci_value?(source, nested)
        agents = RepositoryConfig::ReviewSchema::CI_REVIEW_JOBS
        return !nested.is_a?(Array) if source == agents

        RepositoryConfig::ReviewSchema::RENAMED[source] == agents && !nested.is_a?(String)
      end

      def job_list(source, nested)
        legacy = RepositoryConfig::ReviewSchema::RENAMED[source]
        return [nested] if legacy == RepositoryConfig::ReviewSchema::CI_REVIEW_JOBS && nested.is_a?(String)

        nested
      end

      def store_review(source, key, value)
        @review_sources[key] = source
        @established['review'] ||= {}
        @established['review'][key] = value
      end
    end

    # Maps predecessor seam keys onto typed destinations without guessing policy.
    class FieldClassifier
      include ReviewFields

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
        @review_sources = {}
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
        if key == 'version' && value != 1
          @blocking << 'version'
          return
        end

        @retained << key
        @established[key] = value if %w[base_branch repo_prefix version plan branches recovery].include?(key)
      end

      def classify_merge(value)
        return @blocking << 'merge' unless value.is_a?(Hash) && value.keys.all?(String)

        value.each do |key, nested|
          next store_merge(key, nested) if MERGE_RETAINED.include?(key)
          next record(@retired, "merge.#{key}") if MERGE_RETIRED.include?(key)

          @blocking << "merge.#{key}"
        end
      end

      def store_merge(key, value)
        record(@retained, "merge.#{key}")
        @established['merge'] ||= {}
        @established['merge'][key] = value
      end

      def require_review_and_merge
        required = @established.dig('review', 'required')
        @blocking << 'review.required' unless required
        check = RepositoryConfig::ReviewSchema::CI_REVIEW_JOBS
        @blocking << "review.#{check}" if required && required != 'none' && !@established.dig('review', check)
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
