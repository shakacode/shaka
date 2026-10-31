# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/gitlab/merge_request'

module GitLabMergeRequestHelper
  HEAD = 'a' * 40
  STATUS = Struct.new(:exitstatus)
  Failure = Data.define(:status)

  def project
    { 'id' => 7, 'path_with_namespace' => 'group/sub/project', 'visibility' => 'private',
      'web_url' => 'https://gitlab.example/group/sub/project', 'default_branch' => 'main' }
  end

  def merge_request(**changes)
    { 'id' => 91, 'iid' => 3, 'project_id' => 7, 'target_project_id' => 7, 'source_project_id' => 8,
      'sha' => HEAD, 'source_branch' => 'feature', 'target_branch' => 'main', 'state' => 'opened',
      'draft' => false, 'detailed_merge_status' => 'ci_still_running',
      'diff_refs' => { 'base_sha' => 'b' * 40, 'start_sha' => 'c' * 40, 'head_sha' => HEAD },
      'head_pipeline' => { 'id' => 55, 'sha' => 'd' * 40, 'ref' => 'refs/merge-requests/3/merge' } }.merge(changes)
  end

  def reader(*responses, number: 3)
    @calls = []
    runner = lambda do |argv, stdin_data:|
      @calls << [argv, stdin_data]
      body = responses.shift || raise('Unexpected GitLab request')
      code = body.is_a?(Failure) ? body.status : 200
      body = { 'message' => 'private response token' } if body.is_a?(Failure)
      ["HTTP/2.0 #{code} Status\n\n#{JSON.generate(body)}", 'private stderr', STATUS.new(code == 200 ? 0 : 1)]
    end
    client = Shaka::GitLab.new(host: 'gitlab.example', project: 'group/sub/project', runner:)
    Shaka::GitLab::MergeRequest.new(client:, number:)
  end

  def discussion(id: 'a' * 40, **note_changes)
    { 'id' => id, 'individual_note' => false,
      'notes' => [{ 'id' => 41, 'body' => 'A raw native note.', 'system' => false, 'project_id' => 7,
                    'noteable_id' => 91, 'noteable_type' => 'MergeRequest',
                    'author' => { 'id' => 2, 'username' => 'reviewer', 'bot' => true },
                    'position' => { 'base_sha' => 'b' * 40, 'start_sha' => 'c' * 40, 'head_sha' => HEAD,
                                    'old_path' => 'lib/example.rb', 'new_path' => 'lib/example.rb', 'new_line' => 4,
                                    'position_type' => 'text' } }.merge(note_changes)] }
  end
end

class GitLabMergeRequestDiffTest < Minitest::Test
  include GitLabMergeRequestHelper

  def test_nonempty_diff_refs_require_complete_native_commit_references
    ['unknown', { 'head_sha' => HEAD }, { 'head_sha' => 'short', 'base_sha' => 'b' * 40,
                                          'start_sha' => 'c' * 40 }].each do |diff_refs|
      assert_raises(Shaka::Error) { reader(project, merge_request('diff_refs' => diff_refs)).snapshot }
    end
  end

  def test_unprepared_diff_refs_remain_unknown_instead_of_becoming_source_head_refs
    assert_nil reader(project, merge_request('diff_refs' => nil)).snapshot['diff_refs']
    assert_empty reader(project, merge_request('diff_refs' => {})).snapshot['diff_refs']
  end

  def test_native_pipeline_and_diff_ref_differences_are_not_coerced_to_source_sha
    refs = { 'base_sha' => 'b' * 40, 'start_sha' => 'c' * 40, 'head_sha' => 'e' * 40 }
    snapshot = reader(project, merge_request('diff_refs' => refs)).snapshot
    assert_equal 'a' * 40, snapshot['sha']
    assert_equal 'e' * 40, snapshot.dig('diff_refs', 'head_sha')
    assert_equal 'd' * 40, snapshot.dig('head_pipeline', 'sha')
  end
end

class GitLabMergeRequestDiscussionsTest < Minitest::Test
  include GitLabMergeRequestHelper

  def test_discussions_preserve_raw_author_system_and_diff_position_without_trust_mapping
    native = discussion('system' => true)
    assert_equal [native], reader(project, merge_request, [native]).discussions
    assert_equal 'projects/7/merge_requests/3/discussions?per_page=100&page=1', @calls.last.first[4]
  end

  def test_discussion_shape_failures_do_not_silently_drop_unreadable_evidence
    [{ 'id' => nil }, { 'individual_note' => nil }, { 'notes' => nil }, { 'notes' => [] },
     { 'notes' => ['unreadable'] }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) do
        reader(project, merge_request, [discussion.merge(changes)]).discussions
      end
    end
  end

  def test_note_identity_and_body_shape_must_belong_to_the_requested_merge_request
    [{ 'id' => nil }, { 'project_id' => 8 }, { 'noteable_id' => 92 }, { 'noteable_type' => 'Issue' },
     { 'body' => nil }, { 'system' => nil }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) { reader(project, merge_request, [discussion(**changes)]).discussions }
    end
  end

  def test_missing_author_identity_or_malformed_bot_flag_is_not_trust_evidence
    invalid = [nil, {}, { 'id' => 2 }, { 'id' => '2', 'username' => 'reviewer' },
               { 'id' => 2, 'username' => "reviewer\n" }, { 'id' => 2, 'username' => 'reviewer', 'bot' => 'true' }]
    invalid.each do |author|
      assert_raises(Shaka::Error) do
        reader(project, merge_request, [discussion('author' => author)]).discussions
      end
    end
  end

  def test_malformed_positions_do_not_become_revision_bound_notes
    ['position', {}, { 'head_sha' => HEAD }].each do |position|
      assert_raises(Shaka::Error) do
        reader(project, merge_request, [discussion('position' => position)]).discussions
      end
    end
  end

  def test_discussions_include_later_pages_instead_of_silently_losing_feedback
    first = Array.new(100) { |index| discussion(id: index.to_s) }
    later = discussion(id: 'later-page')
    result = reader(project, merge_request, first, [later]).discussions
    assert_equal 101, result.length
    assert_equal later, result.last
    assert_equal 'projects/7/merge_requests/3/discussions?per_page=100&page=2', @calls.last.first[4]
  end

  def test_missing_native_bot_metadata_or_overview_position_stays_missing
    native = discussion('author' => { 'id' => 2, 'username' => 'reviewer' }, 'position' => nil, 'commit_id' => nil)
    result = reader(project, merge_request, [native]).discussions.first['notes'].first
    refute result['author'].key?('bot')
    assert_nil result['position']
    assert_nil result['commit_id']
  end
end

class GitLabMergeRequestTest < Minitest::Test
  include GitLabMergeRequestHelper

  def test_snapshot_preserves_native_status_fork_and_pipeline_revision_facts
    native = merge_request
    assert_equal native, reader(project, native).snapshot
    assert_equal(['projects/group%2Fsub%2Fproject', 'projects/7/merge_requests/3'], @calls.map { |argv, _| argv[4] })
  end

  def test_wrong_merge_request_or_project_identity_is_not_a_snapshot
    [{ 'id' => nil }, { 'iid' => 4 }, { 'project_id' => 8 }, { 'target_project_id' => 8 },
     { 'source_project_id' => nil }, { 'source_project_id' => '8' }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) { reader(project, merge_request(**changes)).snapshot }
    end
  end

  def test_invalid_merge_request_iid_is_rejected_before_any_authenticated_read
    [0, -1, '--help', '3/notes', '03', "\xff", nil].each do |number|
      assert_raises(Shaka::Error) { reader(number:) }
      assert_empty @calls
    end
  end

  def test_missing_or_malformed_revision_and_branch_fields_fail_closed
    [{ 'sha' => nil }, { 'sha' => 'short' }, { 'source_branch' => '' }, { 'target_branch' => nil },
     { 'target_branch' => "main\n" }, { 'draft' => nil }, { 'state' => nil },
     { 'detailed_merge_status' => nil }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) { reader(project, merge_request(**changes)).snapshot }
    end
  end

  def test_stable_read_yields_native_snapshot_and_returns_block_result_after_reread
    native = merge_request
    value = reader(project, native, project, native).stable_read(head: HEAD, target: 'main') do |snapshot|
      assert_equal native, snapshot
      'collected evidence'
    end
    assert_equal 'collected evidence', value
    assert_equal 4, @calls.length
  end

  def test_stale_head_target_or_closed_state_prevents_evidence_collection
    [{ 'sha' => 'b' * 40 }, { 'target_branch' => 'release' }, { 'state' => 'closed' }].each do |changes|
      ran = false
      assert_raises(Shaka::Error) do
        reader(project, merge_request(**changes)).stable_read(head: HEAD, target: 'main') { ran = true }
      end
      refute ran
    end
  end

  def test_source_or_target_identity_drift_discards_collected_evidence
    [{ 'sha' => 'b' * 40 }, { 'target_branch' => 'release' }, { 'source_project_id' => 9 },
     { 'source_branch' => 'other' }, { 'id' => 92 }, { 'draft' => true },
     { 'diff_refs' => { 'base_sha' => 'b' * 40, 'start_sha' => 'd' * 40, 'head_sha' => HEAD } }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) do
        reader(project, merge_request, project, merge_request(**changes))
          .stable_read(head: HEAD, target: 'main') { 'must not return' }
      end
    end
  end

  def test_invalid_expected_revision_or_target_is_rejected_without_api_reads
    [[nil, 'main'], %w[short main], [HEAD, nil], [HEAD, "main\n"]].each do |head, target|
      instance = reader
      assert_raises(Shaka::Error) { instance.stable_read(head:, target:) { flunk 'invalid expectation yielded' } }
      assert_empty @calls
    end
  end

  def test_block_mutation_cannot_rewrite_the_identity_used_for_the_final_comparison
    instance = reader(project, merge_request, project, merge_request('source_project_id' => 9))
    assert_raises(Shaka::Error) do
      instance.stable_read(head: HEAD, target: 'main') { |first| first['source_project_id'] = 9 }
    end
  end

  def test_api_denials_preserve_native_status_without_relabeling_them_as_missing_support
    [401, 403, 404].each do |status|
      error = assert_raises(Shaka::Error) { reader(project, Failure.new(status:)).snapshot }
      assert_equal status, error.http_status
      refute_match(/private|unsupported/, error.message)
    end
  end
end
