# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/gitlab/gate_reads'

module GitLabGateReadsHelper
  HEAD = 'a' * 40
  TARGET_SHA = 'c' * 40
  STATUS = Struct.new(:exitstatus)
  Failure = Data.define(:status)
  MR_PATH = 'projects/7/merge_requests/3'
  PROJECT_PATH = 'projects/group%2Fsub%2Fproject'
  TARGET_PATH = 'projects/7/repository/branches/main'

  def project(**changes)
    { 'id' => 7, 'path_with_namespace' => 'group/sub/project', 'visibility' => 'private',
      'web_url' => 'https://gitlab.example/group/sub/project', 'default_branch' => 'main',
      'only_allow_merge_if_pipeline_succeeds' => true, 'allow_merge_on_skipped_pipeline' => false,
      'only_allow_merge_if_all_discussions_are_resolved' => true }.merge(changes)
  end

  def merge_request(**changes)
    { 'id' => 91, 'iid' => 3, 'project_id' => 7, 'target_project_id' => 7, 'source_project_id' => 8,
      'sha' => HEAD, 'source_branch' => 'feature', 'target_branch' => 'main', 'state' => 'opened',
      'draft' => false, 'detailed_merge_status' => 'not_approved', 'diff_refs' => nil,
      'head_pipeline' => nil, 'blocking_discussions_resolved' => true }.merge(changes)
  end

  def approvals(**changes)
    { 'approved' => true, 'approvals_required' => 0, 'approvals_left' => 0, 'has_approval_rules' => false,
      'multiple_approval_rules_available' => false, 'merge_request_approvers_available' => false }.merge(changes)
  end

  def target_branch(**changes)
    { 'name' => 'main', 'commit' => { 'id' => TARGET_SHA, 'message' => 'Commit prose stays out of gate evidence.',
                                      'author_name' => 'Contributor' } }.merge(changes)
  end

  def pipeline(**changes)
    { 'id' => 55, 'project_id' => 7, 'source' => 'merge_request_event', 'sha' => HEAD,
      'ref' => 'refs/merge-requests/3/head', 'status' => 'pending' }.merge(changes)
  end

  def job(**changes)
    { 'id' => 88, 'name' => 'verify', 'status' => 'manual', 'allow_failure' => true,
      'pipeline' => pipeline, 'ref' => 'refs/merge-requests/3/head' }.merge(changes)
  end

  def gates(overrides = {})
    routes = { PROJECT_PATH => project, MR_PATH => merge_request, TARGET_PATH => target_branch,
               "#{MR_PATH}/approvals" => approvals,
               "#{MR_PATH}/approval_state" => { 'approval_rules_overwritten' => false, 'rules' => [] },
               "#{MR_PATH}/pipelines?per_page=100&page=1" => [] }.merge(overrides)
    @calls = []
    runner = route_runner(routes)
    client = Shaka::GitLab.new(host: 'gitlab.example', project: 'group/sub/project', runner:)
    Shaka::GitLab::GateReads.new(merge_request: Shaka::GitLab::MergeRequest.new(client:, number: 3))
  end

  def route_runner(routes)
    counts = Hash.new(0)
    lambda do |argv, stdin_data:|
      @calls << [argv, stdin_data]
      path = argv[4]
      counts[path] += 1
      value = routes.fetch(path) { raise "Unexpected GitLab endpoint #{path}" }
      value = value.call(counts[path]) if value.respond_to?(:call)
      http_response(value)
    end
  end

  def http_response(value)
    code = value.is_a?(Failure) ? value.status : 200
    value = { 'message' => 'private response token' } if value.is_a?(Failure)
    ["HTTP/2.0 #{code} Status\n\n#{JSON.generate(value)}", 'private stderr', STATUS.new(code == 200 ? 0 : 1)]
  end
end

class GitLabGateTargetRevisionTest < Minitest::Test
  include GitLabGateReadsHelper

  def test_target_revision_preserves_only_exact_branch_name_and_commit_id_between_two_reads
    result = gates.call(head: HEAD, target: 'main')
    assert_equal({ 'availability' => 'available', 'data' => { 'name' => 'main', 'commit' => { 'id' => TARGET_SHA } } },
                 result['target_revision'])
    assert_equal(2, @calls.count { |argv, _| argv[4] == TARGET_PATH })
  end

  def test_target_commit_advancing_under_the_same_branch_name_discards_evidence
    branch = ->(count) { count == 1 ? target_branch : target_branch('commit' => { 'id' => 'd' * 40 }) }
    assert_raises(Shaka::Error) { gates(TARGET_PATH => branch).call(head: HEAD, target: 'main') }
  end

  def test_wrong_or_malformed_target_branch_facts_are_unknown
    [{ 'name' => 'release' }, { 'commit' => nil }, { 'commit' => { 'id' => 'short' } }].each do |changes|
      result = gates(TARGET_PATH => target_branch(**changes)).call(head: HEAD, target: 'main')
      assert_equal({ 'availability' => 'unknown' }, result['target_revision'])
    end
  end

  def test_reviewed_target_sha_is_required_when_the_caller_supplies_it
    assert_raises(Shaka::Error) { gates.call(head: HEAD, target: 'main', target_sha: 'd' * 40) }
    refute(@calls.any? { |argv, _| argv[4] == "#{MR_PATH}/approvals" })
    assert_equal TARGET_SHA, gates.call(head: HEAD, target: 'main', target_sha: TARGET_SHA)
                                  .dig('target_revision', 'data', 'commit', 'id')
  end

  def test_invalid_expected_target_sha_is_rejected_before_api_reads
    instance = gates
    assert_raises(Shaka::Error) { instance.call(head: HEAD, target: 'main', target_sha: 'short') }
    assert_empty @calls
  end

  def test_unavailable_target_reads_do_not_become_a_satisfied_expected_target
    { 401 => 'unavailable-access', 403 => 'unavailable-access', 404 => 'unknown',
      429 => 'unavailable-service', 500 => 'unavailable-service' }.each do |status, availability|
      result = gates(TARGET_PATH => Failure.new(status:)).call(head: HEAD, target: 'main', target_sha: TARGET_SHA)
      assert_equal({ 'availability' => availability, 'http_status' => status }, result['target_revision'])
    end
  end

  def test_lost_target_readback_does_not_release_the_initial_available_revision
    route = ->(count) { count == 1 ? target_branch : Failure.new(status: 403) }
    result = gates(TARGET_PATH => route).call(head: HEAD, target: 'main')
    assert_equal({ 'availability' => 'unavailable-access', 'http_status' => 403 }, result['target_revision'])
  end

  def test_final_readable_target_mismatch_is_rejected_after_an_unavailable_first_read
    route = lambda do |count|
      count == 1 ? Failure.new(status: 403) : target_branch('commit' => { 'id' => 'd' * 40 })
    end
    assert_raises(Shaka::Error) do
      gates(TARGET_PATH => route).call(head: HEAD, target: 'main', target_sha: TARGET_SHA)
    end
  end

  def test_requested_target_path_is_encoded_without_losing_branch_identity
    target = 'release/週+next'
    path = 'projects/7/repository/branches/release%2F%E9%80%B1%2Bnext'
    result = gates(MR_PATH => merge_request('target_branch' => target), path => target_branch('name' => target))
             .call(head: HEAD, target: target)
    assert_equal target, result.dig('target_revision', 'data', 'name')
    count = @calls.count { |argv, _| argv[4] == path }
    assert_equal 2, count
  end
end

class GitLabGateStabilityTest < Minitest::Test
  include GitLabGateReadsHelper

  def test_final_stability_snapshot_cannot_hide_new_pipeline_or_unresolved_discussions
    [{ 'head_pipeline' => pipeline }, { 'blocking_discussions_resolved' => false }].each do |changes|
      route = ->(count) { count < 3 ? merge_request : merge_request(**changes) }
      assert_raises(Shaka::Error) { gates(MR_PATH => route).call(head: HEAD, target: 'main') }
    end
  end

  def test_head_or_target_drift_discards_gate_evidence
    [{ 'sha' => 'b' * 40 }, { 'target_branch' => 'release' }].each do |changes|
      route = ->(count) { count == 1 ? merge_request : merge_request(**changes) }
      assert_raises(Shaka::Error) { gates(MR_PATH => route).call(head: HEAD, target: 'main') }
    end
  end

  def test_requirement_changes_during_reads_are_not_a_stable_policy_snapshot
    route = ->(count) { count < 4 ? project : project('only_allow_merge_if_pipeline_succeeds' => false) }
    assert_raises(Shaka::Error) { gates(PROJECT_PATH => route).call(head: HEAD, target: 'main') }
  end

  def test_native_head_pipeline_replacement_cannot_leave_old_pipeline_evidence_current
    route = ->(count) { count == 1 ? merge_request : merge_request('head_pipeline' => pipeline) }
    assert_raises(Shaka::Error) { gates(MR_PATH => route).call(head: HEAD, target: 'main') }
  end
end

class GitLabGateReadsTest < Minitest::Test
  include GitLabGateReadsHelper

  def test_approval_packets_keep_only_gate_facts_without_mr_prose_or_unrelated_user_records
    rules = [{ 'id' => 8, 'approvals_required' => 1, 'approved' => false }]
    state = { 'approval_rules_overwritten' => false, 'rules' => rules }
    raw_rule = rules.first.merge('name' => 'Rule label', 'users' => [{ 'name' => 'Unrelated user' }])
    result = gates("#{MR_PATH}/approvals" => approvals('title' => 'Untrusted title',
                                                       'description' => 'Untrusted instructions',
                                                       'approved_by' => [{ 'user' => { 'name' => 'Unrelated user' } }]),
                   "#{MR_PATH}/approval_state" => state.merge('rules' => [raw_rule]))
             .call(head: HEAD, target: 'main')
    assert_equal approvals, result.dig('approvals', 'data')
    assert_equal state, result.dig('approval_state', 'data')
  end

  def test_native_requirements_and_empty_pipelines_are_explicit_without_a_ready_verdict
    result = gates.call(head: HEAD, target: 'main')
    assert_equal({ 'availability' => 'available', 'value' => true },
                 result.dig('requirements', 'only_allow_merge_if_pipeline_succeeds'))
    assert_equal 'absent', result.dig('pipelines', 'availability')
    assert_equal 'absent', result.dig('head_pipeline', 'availability')
    refute result.key?('ready')
    assert_equal HEAD, result.dig('merge_request', 'sha')
    assert_equal 'not_approved', result.dig('merge_request', 'detailed_merge_status')
  end

  def test_missing_head_pipeline_field_is_unknown_rather_than_known_absent
    native = merge_request.except('head_pipeline')
    result = gates(MR_PATH => native).call(head: HEAD, target: 'main')
    assert_equal({ 'availability' => 'unknown' }, result['head_pipeline'])
  end

  def test_missing_nonboolean_requirements_and_resolution_facts_remain_unknown
    result = gates(PROJECT_PATH => project('only_allow_merge_if_pipeline_succeeds' => nil,
                                           'allow_merge_on_skipped_pipeline' => 'false'),
                   MR_PATH => merge_request('blocking_discussions_resolved' => nil)).call(head: HEAD, target: 'main')
    assert_equal 'unknown', result.dig('requirements', 'only_allow_merge_if_pipeline_succeeds', 'availability')
    assert_equal 'unknown', result.dig('requirements', 'allow_merge_on_skipped_pipeline', 'availability')
    assert_equal 'unknown', result.dig('blocking_discussions_resolved', 'availability')
  end

  def test_free_tier_approval_facts_are_preserved_without_inventing_paid_rule_support
    result = gates.call(head: HEAD, target: 'main')
    assert_equal({ 'availability' => 'available', 'data' => approvals }, result['approvals'])
    assert_equal({ 'availability' => 'available',
                   'data' => { 'approval_rules_overwritten' => false, 'rules' => [] } }, result['approval_state'])
  end

  def test_api_access_and_service_failures_remain_distinct_from_unknown_404_capability
    { 401 => 'unavailable-access', 403 => 'unavailable-access', 404 => 'unknown',
      429 => 'unavailable-service', 500 => 'unavailable-service' }.each do |status, availability|
      result = gates("#{MR_PATH}/approvals" => Failure.new(status:)).call(head: HEAD, target: 'main')
      assert_equal({ 'availability' => availability, 'http_status' => status }, result['approvals'])
      assert_equal 'available', result.dig('approval_state', 'availability')
    end
  end

  def test_empty_or_malformed_approval_responses_do_not_become_satisfied_gates
    [{}, { 'approved' => 'true' }, approvals('approvals_left' => -1), approvals('iid' => 4),
     approvals('project_id' => 8), approvals('id' => 92), approvals('has_approval_rules' => 'false')].each do |value|
      result = gates("#{MR_PATH}/approvals" => value).call(head: HEAD, target: 'main')
      assert_equal({ 'availability' => 'unknown' }, result['approvals'])
    end
  end

  def test_rule_approval_state_preserves_unapproved_rule_instead_of_using_approved_by_as_a_gate
    state = { 'approval_rules_overwritten' => false,
              'rules' => [{ 'id' => 8, 'approvals_required' => 1, 'approved' => false }] }
    result = gates("#{MR_PATH}/approval_state" => state).call(head: HEAD, target: 'main')
    assert_equal({ 'availability' => 'available', 'data' => state }, result['approval_state'])
  end

  def test_missing_or_malformed_approval_rules_remain_unknown
    [{}, { 'rules' => nil }, { 'approval_rules_overwritten' => false, 'rules' => [{}] }].each do |state|
      result = gates("#{MR_PATH}/approval_state" => state).call(head: HEAD, target: 'main')
      assert_equal({ 'availability' => 'unknown' }, result['approval_state'])
    end
  end
end

class GitLabGatePipelineReadsTest < Minitest::Test
  include GitLabGateReadsHelper

  def test_job_scope_excludes_trigger_jobs_and_omits_untrusted_prose_and_runner_details
    native = pipeline('commit' => { 'message' => 'Untrusted commit prose' })
    build = job('commit' => { 'message' => 'Untrusted commit prose' },
                'runner' => { 'description' => 'Internal runner' })
    result = gates(MR_PATH => merge_request('head_pipeline' => pipeline), 'projects/7/pipelines/55' => native,
                   "#{MR_PATH}/pipelines?per_page=100&page=1" => [native],
                   'projects/7/pipelines/55/jobs?per_page=100&page=1' => [build]).call(head: HEAD, target: 'main')
    assert_equal pipeline, result.dig('head_pipeline', 'data')
    assert_equal [pipeline], result.dig('pipelines', 'data')
    assert_equal [job], result.dig('head_pipeline', 'jobs', 'data')
  end

  def test_head_pipeline_and_jobs_preserve_manual_and_allowed_failure_native_facts
    result = gates(MR_PATH => merge_request('head_pipeline' => pipeline),
                   "#{MR_PATH}/pipelines?per_page=100&page=1" => [pipeline],
                   'projects/7/pipelines/55' => pipeline,
                   'projects/7/pipelines/55/jobs?per_page=100&page=1' => [job]).call(head: HEAD, target: 'main')
    assert_equal 'build-jobs-only', result.dig('head_pipeline', 'jobs', 'coverage')
    assert_equal pipeline, result.dig('head_pipeline', 'data')
    assert_equal [job], result.dig('head_pipeline', 'jobs', 'data')
  end

  def test_a_successful_list_entry_does_not_replace_an_absent_native_head_pipeline
    result = gates("#{MR_PATH}/pipelines?per_page=100&page=1" => [pipeline('status' => 'success')])
             .call(head: HEAD, target: 'main')
    assert_equal 'available', result.dig('pipelines', 'availability')
    assert_equal 'absent', result.dig('head_pipeline', 'availability')
    refute(@calls.any? { |argv, _| argv[4] == 'projects/7/pipelines/55' })
  end

  def test_integration_pipeline_sha_is_preserved_separately_from_source_revision
    native = pipeline('sha' => 'e' * 40, 'ref' => 'refs/merge-requests/3/merge', 'status' => 'success')
    result = gates(MR_PATH => merge_request('head_pipeline' => native), 'projects/7/pipelines/55' => native,
                   'projects/7/pipelines/55/jobs?per_page=100&page=1' => []).call(head: HEAD, target: 'main')
    assert_false result.dig('head_pipeline', 'source_sha_matches')
    assert_equal native, result.dig('head_pipeline', 'data')
    assert_equal [HEAD, TARGET_SHA, 'e' * 40],
                 [result.dig('merge_request', 'sha'), result.dig('target_revision', 'data', 'commit', 'id'),
                  result.dig('head_pipeline', 'data', 'sha')]
  end

  def test_wrong_pipeline_identity_or_revision_is_unknown_instead_of_current_head_evidence
    [{ 'id' => 56 }, { 'project_id' => 8 }, { 'sha' => 'e' * 40 }, { 'ref' => 'other' }].each do |changes|
      result = gates(MR_PATH => merge_request('head_pipeline' => pipeline),
                     'projects/7/pipelines/55' => pipeline(**changes),
                     'projects/8/pipelines/55/jobs?per_page=100&page=1' => [],
                     'projects/7/pipelines/56/jobs?per_page=100&page=1' => [],
                     'projects/7/pipelines/55/jobs?per_page=100&page=1' => []).call(head: HEAD, target: 'main')
      assert_equal({ 'availability' => 'unknown' }, result['head_pipeline'])
    end
  end

  def test_missing_pipeline_project_is_unknown_and_does_not_default_to_target_project
    result = gates(MR_PATH => merge_request('head_pipeline' => pipeline.except('project_id')))
             .call(head: HEAD, target: 'main')
    assert_equal({ 'availability' => 'unknown' }, result['head_pipeline'])
    refute(@calls.any? { |argv, _| argv[4] == 'projects/7/pipelines/55' })
  end

  def test_a_fork_source_pipeline_is_read_from_its_native_source_project
    native = pipeline('project_id' => 8)
    result = gates(MR_PATH => merge_request('head_pipeline' => native), 'projects/8/pipelines/55' => native,
                   'projects/8/pipelines/55/jobs?per_page=100&page=1' => []).call(head: HEAD, target: 'main')
    assert_equal native, result.dig('head_pipeline', 'data')
    assert_true result.dig('head_pipeline', 'source_sha_matches')
  end

  def test_malformed_pipeline_list_does_not_become_complete_available_evidence
    [[{}], [pipeline('sha' => 'short')], [pipeline('status' => nil)]].each do |records|
      result = gates("#{MR_PATH}/pipelines?per_page=100&page=1" => records).call(head: HEAD, target: 'main')
      assert_equal({ 'availability' => 'unknown' }, result['pipelines'])
    end
  end

  def test_failed_and_skipped_pipeline_states_are_not_normalized_to_success
    %w[pending failed skipped manual success].each do |status|
      native = pipeline('status' => status)
      result = gates("#{MR_PATH}/pipelines?per_page=100&page=1" => [native]).call(head: HEAD, target: 'main')
      assert_equal [native], result.dig('pipelines', 'data')
    end
  end

  def test_jobs_from_another_pipeline_or_without_native_policy_fields_are_unknown
    [job('allow_failure' => nil), job('status' => nil), job('pipeline' => pipeline('id' => 56))].each do |native|
      result = gates(MR_PATH => merge_request('head_pipeline' => pipeline), 'projects/7/pipelines/55' => pipeline,
                     'projects/7/pipelines/55/jobs?per_page=100&page=1' => [native]).call(head: HEAD, target: 'main')
      assert_equal({ 'availability' => 'unknown' }, result.dig('head_pipeline', 'jobs'))
    end
  end

  def test_later_page_jobs_and_allowed_failures_are_not_lost
    first = Array.new(100) { |index| job('id' => index + 1, 'status' => 'success', 'allow_failure' => false) }
    later = job('id' => 101, 'status' => 'failed', 'allow_failure' => true)
    result = gates(MR_PATH => merge_request('head_pipeline' => pipeline), 'projects/7/pipelines/55' => pipeline,
                   'projects/7/pipelines/55/jobs?per_page=100&page=1' => first,
                   'projects/7/pipelines/55/jobs?per_page=100&page=2' => [later]).call(head: HEAD, target: 'main')
    assert_equal 101, result.dig('head_pipeline', 'jobs', 'data').length
    assert_equal later, result.dig('head_pipeline', 'jobs', 'data').last
  end

  def test_denied_jobs_do_not_hide_readable_pipeline_or_become_an_empty_success_list
    result = gates(MR_PATH => merge_request('head_pipeline' => pipeline), 'projects/7/pipelines/55' => pipeline,
                   'projects/7/pipelines/55/jobs?per_page=100&page=1' => Failure.new(status: 403))
             .call(head: HEAD, target: 'main')
    assert_equal 'available', result.dig('head_pipeline', 'availability')
    assert_equal({ 'availability' => 'unavailable-access', 'http_status' => 403 }, result.dig('head_pipeline', 'jobs'))
  end
end
