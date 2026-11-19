# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/gitlab/comments'

module GitLabCommentsFixture
  HEAD = 'b' * 40
  STATUS = Struct.new(:exitstatus)
  Failure = Data.define(:status)

  def setup
    @calls = []
    @counts = Hash.new(0)
    @data = { 'projects/group%2Fsub%2Frepo' => project,
              'projects/7/merge_requests/1' => native_mr,
              'projects/7/merge_requests/1/discussions?per_page=100&page=1' => discussions }
  end

  def project
    { 'id' => 7, 'path_with_namespace' => 'group/sub/repo', 'visibility' => 'private',
      'web_url' => 'https://gitlab.example/group/sub/repo', 'default_branch' => 'main' }
  end

  def native_mr
    { 'id' => 123, 'iid' => 1, 'project_id' => 7, 'source_project_id' => 7, 'target_project_id' => 7,
      'source_branch' => 'feature', 'target_branch' => 'main', 'sha' => HEAD, 'state' => 'opened',
      'draft' => false, 'detailed_merge_status' => 'mergeable', 'diff_refs' => nil }
  end

  def discussions
    [{ 'id' => 'c' * 40, 'individual_note' => true, 'notes' => [
      { 'id' => 11, 'project_id' => 7, 'noteable_id' => 123, 'noteable_type' => 'MergeRequest',
        'body' => 'Check the expected revision.', 'system' => false, 'author' => { 'id' => 42, 'username' => 'alice' } }
    ] }]
  end

  def reader
    runner = lambda do |argv, stdin_data:|
      @calls << [argv, stdin_data]
      path = argv[4]
      @counts[path] += 1
      value = @data.fetch(path)
      value = value.call(@counts[path]) if value.respond_to?(:call)
      response(value)
    end
    client = Shaka::GitLab.new(host: 'gitlab.example', project: 'group/sub/repo', runner:)
    Shaka::GitLab::Comments.new(merge_request: Shaka::GitLab::MergeRequest.new(client:, number: 1))
  end

  def response(value)
    code = value.is_a?(Failure) ? value.status : 200
    value = { 'message' => 'PRIVATE FAILURE BODY' } if value.is_a?(Failure)
    ["HTTP/2.0 #{code} Status\n\n#{JSON.generate(value)}", '', STATUS.new(code == 200 ? 0 : 1)]
  end

  def public_context
    @data['projects/group%2Fsub%2Frepo'] = project.merge('visibility' => 'public')
    @data['projects/7/repository/branches/main'] =
      { 'name' => 'main', 'default' => true, 'commit' => { 'id' => 'a' * 40 } }
    text = "trusted_users: [{id: 42, username: alice}]\n"
    @data["projects/7/repository/files/.agents%2Fshaka%2Ftrusted-gitlab-actors.yml?ref=#{'a' * 40}"] =
      policy_payload(text)
    @data['users/42'] = { 'id' => 42, 'username' => 'alice', 'state' => 'active', 'bot' => false }
  end

  def policy_payload(text)
    path = '.agents/shaka/trusted-gitlab-actors.yml'
    {
      'file_path' => path, 'ref' => 'a' * 40, 'commit_id' => 'a' * 40, 'encoding' => 'base64',
      'size' => text.bytesize, 'content' => [text].pack('m0'), 'content_sha256' => Digest::SHA256.hexdigest(text)
    }
  end

  def stranger_context
    public_context
    note = { 'id' => 12, 'project_id' => 7, 'noteable_id' => 123, 'noteable_type' => 'MergeRequest',
             'body' => 'UNTRUSTED SECRET PROSE', 'system' => false,
             'author' => { 'id' => 43, 'username' => 'stranger' } }
    @data['projects/7/merge_requests/1/discussions?per_page=100&page=1'].first['notes'] << note
    @data['users/43'] = { 'id' => 43, 'username' => 'stranger', 'state' => 'active', 'bot' => false }
    @data['projects/7/members/all/43'] = Failure.new(404)
  end

  def policy_error_context(status)
    public_context
    @data["projects/7/repository/files/.agents%2Fshaka%2Ftrusted-gitlab-actors.yml?ref=#{'a' * 40}"] =
      Failure.new(status)
  end

  def change_default_on_final_mr_read
    public_context
    @data['projects/7/repository/branches/next'] =
      { 'name' => 'next', 'default' => true, 'commit' => { 'id' => 'd' * 40 } }
    @data["projects/7/repository/files/.agents%2Fshaka%2Ftrusted-gitlab-actors.yml?ref=#{'d' * 40}"] =
      policy_payload("trusted_users: []\n").merge('ref' => 'd' * 40, 'commit_id' => 'd' * 40)
    @data['projects/7/merge_requests/1'] = lambda { |count|
      @data['projects/group%2Fsub%2Frepo']['default_branch'] = 'next' if count > 2
      native_mr
    }
  end
end

class GitLabCommentsTest < Minitest::Test
  include GitLabCommentsFixture

  def test_internal_visibility_is_unsupported_before_any_discussion_body_is_read
    @data['projects/group%2Fsub%2Frepo'] = project.merge('visibility' => 'internal')
    assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
    refute(@calls.any? { |argv, _| argv[4].include?('/discussions') })
  end

  def test_private_discussion_read_retains_prose_at_a_verified_head_and_target
    result = reader.call(head: HEAD, target: 'main')
    assert_equal 'Check the expected revision.', result.fetch('notes').first.fetch('body')
    assert_equal HEAD, result.fetch('head')
    assert_equal 'private', result.fetch('visibility')
    assert_empty result.fetch('trust_sources')
  end

  def test_public_prose_requires_native_actor_evidence_and_default_commit_trust_source
    public_context
    result = reader.call(head: HEAD, target: 'main')
    assert_equal 'configured_user', result.fetch('notes').first.fetch('trust')
    assert_equal 'a' * 40, result.fetch('trust_sources').first.fetch('commit')
    assert_includes @calls.map { |argv, _| argv[4] }, 'users/42'
  end

  def test_visibility_change_during_private_read_cannot_release_unscreened_prose
    @data['projects/group%2Fsub%2Frepo'] = lambda { |count|
      project.merge('visibility' => count <= 3 ? 'private' : 'public')
    }
    assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
  end

  def test_readable_notes_preserve_native_diff_positions_without_claiming_current_head_binding
    position = { 'position_type' => 'text', 'base_sha' => 'a' * 40, 'start_sha' => 'a' * 40,
                 'head_sha' => 'd' * 40, 'new_path' => 'app.rb', 'new_line' => 4 }
    @data['projects/7/merge_requests/1/discussions?per_page=100&page=1'].first['notes'].first['position'] = position
    assert_equal position, reader.call(head: HEAD, target: 'main').fetch('notes').first.fetch('position')
  end

  def test_duplicate_native_note_ids_cannot_overwrite_position_or_actor_evidence
    @data['projects/7/merge_requests/1/discussions?per_page=100&page=1'] = discussions * 2
    assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
  end
end

class GitLabCommentsFailureTest < Minitest::Test
  include GitLabCommentsFixture

  def test_visibility_observed_on_the_final_project_read_cannot_release_private_prose
    @data['projects/group%2Fsub%2Frepo'] = lambda { |count|
      project.merge('visibility' => count <= 4 ? 'private' : 'public')
    }
    assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
  end

  def test_missing_optional_actor_file_still_allows_a_verified_project_writer
    policy_error_context(404)
    @data['projects/7/members/all/42'] =
      { 'id' => 42, 'username' => 'alice', 'state' => 'active', 'access_level' => 30, 'expires_at' => nil }

    result = reader.call(head: HEAD, target: 'main')
    assert_equal 'writer', result.fetch('notes').first.fetch('trust')
    assert_equal({ 'state' => 'absent', 'sha256' => nil },
                 result.fetch('trust_sources').first.slice('state', 'sha256'))
  end

  def test_policy_denials_and_unavailability_do_not_become_an_empty_scope
    [401, 403, 429, 500].each do |status|
      policy_error_context(status)
      error = assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
      assert_equal status, error.http_status
    end
  end

  def test_default_branch_change_at_the_final_mr_read_discards_old_actor_settings
    change_default_on_final_mr_read
    error = assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
    assert_includes error.message, 'trusted actor source changed'
  end

  def test_unknown_public_author_prose_is_withheld_while_configured_prose_survives
    stranger_context
    result = reader.call(head: HEAD, target: 'main')
    assert_equal([11], result.fetch('notes').map { it['id'] })
    assert_equal([12], result.fetch('withheld').map { it['id'] })
    refute_includes JSON.generate(result), 'UNTRUSTED SECRET PROSE'
  end

  def test_later_page_denial_returns_no_partial_packet_or_private_error_body
    public_context
    @data['projects/7/merge_requests/1/discussions?per_page=100&page=1'] = discussions * 100
    @data['projects/7/merge_requests/1/discussions?per_page=100&page=2'] = Failure.new(403)

    error = assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
    assert_equal 403, error.http_status
    refute_includes error.message, 'PRIVATE FAILURE BODY'
    refute(@calls.any? { |argv, _| argv[4] == 'users/42' })
  end

  def test_changed_trust_source_discards_the_screened_packet
    public_context
    policy = "projects/7/repository/files/.agents%2Fshaka%2Ftrusted-gitlab-actors.yml?ref=#{'a' * 40}"
    @data[policy] = lambda { |count|
      policy_payload(count == 1 ? "trusted_users: [{id: 42, username: alice}]\n" : "trusted_users: []\n")
    }

    error = assert_raises(Shaka::Error) { reader.call(head: HEAD, target: 'main') }
    assert_includes error.message, 'trusted actor source changed'
  end
end
