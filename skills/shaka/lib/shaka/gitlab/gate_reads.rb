# frozen_string_literal: true

require_relative 'merge_request'

module Shaka
  class GitLab
    # Checks readable native facts without treating missing fields as satisfied gates.
    module GateValidation
      APPROVAL_FLAGS = %w[approved has_approval_rules multiple_approval_rules_available
                          merge_request_approvers_available].freeze
      APPROVAL_FIELDS = (%w[id iid project_id approvals_required approvals_left] + APPROVAL_FLAGS).freeze

      private

      def validate_approvals(data, snapshot)
        valid = identity_fields_match?(data, snapshot) && approval_flags?(data) &&
                %w[approvals_required approvals_left].all? { |key| !data.key?(key) || count?(data[key]) }
        raise Error, 'Malformed GitLab approval evidence.' unless valid

        data.slice(*APPROVAL_FIELDS)
      end

      def approval_flags?(data)
        boolean?(data['approved']) && APPROVAL_FLAGS.all? { |key| !data.key?(key) || boolean?(data[key]) }
      end

      def identity_fields_match?(data, snapshot)
        %w[id iid project_id].all? { |key| !data.key?(key) || data[key] == snapshot[key] }
      end

      def validate_approval_state(data, snapshot)
        valid = identity_fields_match?(data, snapshot) && boolean?(data['approval_rules_overwritten']) &&
                data['rules'].is_a?(Array) && data['rules'].all? { |rule| approval_rule?(rule) }
        raise Error, 'Malformed GitLab approval-state evidence.' unless valid

        data.slice('id', 'iid', 'project_id', 'approval_rules_overwritten')
            .merge('rules' => data['rules'].map { |rule| rule.slice('id', 'approvals_required', 'approved') })
      end

      def approval_rule?(rule)
        rule.is_a?(Hash) && count?(rule['approvals_required']) && boolean?(rule['approved']) &&
          (!rule.key?('id') || positive_id?(rule['id']))
      end

      def boolean?(value) = [true, false].include?(value)
      def count?(value) = value.is_a?(Integer) && value >= 0
      def positive_id?(value) = value.is_a?(Integer) && value.positive?
      def commit?(value) = value.is_a?(String) && value.ascii_only? && value.match?(/\A[0-9a-f]{40}\z/)
      def text?(value) = value.is_a?(String) && value.valid_encoding? && !value.strip.empty?

      def pipeline_record?(data)
        data.is_a?(Hash) && positive_id?(data['id']) && commit?(data['sha']) &&
          text?(data['ref']) && text?(data['status'])
      end
    end

    # Head-pipeline evidence comes from its native ID, never from a successful list entry.
    module GatePipelineReads
      PIPELINE_IDENTITY = %w[id project_id sha ref].freeze
      PIPELINE_FIELDS = (PIPELINE_IDENTITY + %w[status source]).freeze
      JOB_FIELDS = %w[id name status allow_failure stage ref].freeze

      private

      def head_pipeline(snapshot, head)
        return { 'availability' => 'unknown' } unless snapshot.key?('head_pipeline')

        reference = snapshot['head_pipeline']
        return { 'availability' => 'absent' } if reference.nil?

        result = observe { read_head_pipeline(reference, snapshot) }
        return result unless result['availability'] == 'available'

        data = result.fetch('data')
        result.merge('source_sha_matches' => data['sha'] == head, 'jobs' => pipeline_jobs(data))
      end

      def pipeline_jobs(pipeline)
        result = observe do
          data = @client.api_list("projects/#{pipeline['project_id']}/pipelines/#{pipeline['id']}/jobs")
          raise Error, 'Malformed GitLab job evidence.' unless data.all? { |job| job_record?(job, pipeline) }

          data.map { |job| job.slice(*JOB_FIELDS).merge('pipeline' => job['pipeline'].slice(*PIPELINE_FIELDS)) }
        end
        return result unless %w[available absent].include?(result['availability'])

        result.merge('coverage' => 'build-jobs-only')
      end

      def read_head_pipeline(reference, snapshot)
        raise Error, 'Missing native head-pipeline identity.' unless head_reference?(reference, snapshot)

        data = @client.api("projects/#{reference['project_id']}/pipelines/#{reference['id']}")
        unless pipeline_record?(data) && text?(data['source']) && same_pipeline?(data, reference)
          raise Error, 'GitLab pipeline identity did not match the native head pipeline.'
        end

        data.slice(*PIPELINE_FIELDS)
      end

      def head_reference?(reference, snapshot)
        reference.is_a?(Hash) && positive_id?(reference['id']) && commit?(reference['sha']) &&
          text?(reference['ref']) && snapshot.values_at('source_project_id', 'target_project_id')
                                             .include?(reference['project_id'])
      end

      def same_pipeline?(data, reference)
        data.values_at(*PIPELINE_IDENTITY) == reference.values_at(*PIPELINE_IDENTITY)
      end

      def job_record?(job, pipeline)
        positive_id?(job['id']) && text?(job['name']) && text?(job['status']) && boolean?(job['allow_failure']) &&
          job['pipeline'].is_a?(Hash) && same_pipeline?(job['pipeline'], pipeline)
      end
    end

    # Target commits are native branch facts, distinct from source and integration SHAs.
    module GateTargetReads
      private

      def with_target_revision(project, target, target_sha)
        first = target_revision(project, target)
        verify_reviewed_target(first, target_sha)
        result = yield
        last = target_revision(project, target)
        verify_reviewed_target(last, target_sha)
        result.merge('target_revision' => stable_target_revision(first, last))
      end

      def verify_reviewed_target(evidence, target_sha)
        return if target_sha.nil? || evidence['availability'] != 'available'
        return if evidence.dig('data', 'commit', 'id') == target_sha

        raise Error, 'GitLab target revision does not match the reviewed target commit.'
      end

      def stable_target_revision(first, last)
        return first unless first['availability'] == 'available'
        return last unless last['availability'] == 'available'

        raise Error, 'GitLab target revision changed during the read.' unless first['data'] == last['data']

        last
      end

      def target_revision(project, target)
        observe do
          encoded = URI.encode_www_form_component(target)
          data = @client.api("projects/#{project.fetch('id')}/repository/branches/#{encoded}")
          commit = data['commit']
          unless data['name'] == target && commit.is_a?(Hash) && commit?(commit['id'])
            raise Error, 'GitLab target branch did not return the requested named commit.'
          end

          { 'name' => data['name'], 'commit' => { 'id' => commit['id'] } }
        end
      end
    end

    # Native evidence and its availability; readiness remains the caller's decision.
    class GateReads
      include GateValidation
      include GatePipelineReads
      include GateTargetReads

      REQUIREMENTS = %w[only_allow_merge_if_pipeline_succeeds allow_merge_on_skipped_pipeline
                        only_allow_merge_if_all_discussions_are_resolved].freeze

      def initialize(merge_request:)
        @mr = merge_request
        @client = @mr.client
      end

      def call(head:, target:, target_sha: nil)
        raise Error, 'Expected a full target commit SHA.' unless target_sha.nil? || commit?(target_sha)

        @mr.stable_read(head:, target:, verify: method(:verify_final_context)) do |snapshot|
          project = @client.project
          with_target_revision(project, target, target_sha) do
            collect(snapshot, project, head)
              .tap { verify_native_context(snapshot, project) }
          end
        end
      end

      private

      def collect(snapshot, project, head)
        path = @mr.path
        { 'merge_request' => snapshot.slice(*MergeRequest::IDENTITY, 'state', 'detailed_merge_status'),
          'requirements' => REQUIREMENTS.to_h { |key| [key, boolean_evidence(project[key])] },
          'approvals' => observe { validate_approvals(@client.api("#{path}/approvals"), snapshot) },
          'approval_state' => observe { validate_approval_state(@client.api("#{path}/approval_state"), snapshot) },
          'pipelines' => pipeline_list(path), 'head_pipeline' => head_pipeline(snapshot, head),
          'blocking_discussions_resolved' => boolean_evidence(snapshot['blocking_discussions_resolved']) }
      end

      def verify_native_context(snapshot, project)
        current = @client.project
        unless project.slice('id', *REQUIREMENTS) == current.slice('id', *REQUIREMENTS) &&
               native_context(snapshot) == native_context(@mr.snapshot)
          raise Error, 'GitLab requirements or native head-pipeline context changed during the read.'
        end
      end

      def native_context(snapshot)
        reference = snapshot['head_pipeline']
        reference = reference.slice(*PIPELINE_IDENTITY) if reference.is_a?(Hash)
        [snapshot.key?('head_pipeline'), reference, snapshot['blocking_discussions_resolved']]
      end

      def verify_final_context(first, last)
        return if native_context(first) == native_context(last)

        raise Error, 'GitLab native gate context changed at the final MR read.'
      end

      def observe
        data = yield
        { 'availability' => data.is_a?(Array) && data.empty? ? 'absent' : 'available', 'data' => data }
      rescue Error => e
        { 'availability' => unavailability(e.http_status), 'http_status' => e.http_status }.compact
      end

      def unavailability(status)
        case status
        when 401, 403 then 'unavailable-access'
        when 429, 500..599 then 'unavailable-service'
        else 'unknown'
        end
      end

      def boolean_evidence(value)
        return { 'availability' => 'unknown' } unless [true, false].include?(value)

        { 'availability' => 'available', 'value' => value }
      end

      def pipeline_list(path)
        observe do
          data = @client.api_list("#{path}/pipelines")
          raise Error, 'Malformed GitLab pipeline list.' unless data.all? { |pipeline| pipeline_record?(pipeline) }

          data.map { |pipeline| pipeline.slice(*PIPELINE_FIELDS) }
        end
      end
    end
  end
end
