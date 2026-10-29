# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/gitlab/actor_trust'

module GitLabActorFixtures
  STATUS = Struct.new(:exitstatus)
  DISCUSSION = 'a' * 40

  def setup
    @calls = []
    @counts = Hash.new(0)
    @data = { 'projects/group%2Fsub%2Frepo' => project,
              'projects/7/members/all/42' => nil, 'users/42' => user }
    @api_failures = {}
  end

  def project
    { 'id' => 7, 'path_with_namespace' => 'group/sub/repo', 'visibility' => 'public',
      'web_url' => 'https://gitlab.example/group/sub/repo', 'default_branch' => 'main' }
  end

  def user = { 'id' => 42, 'username' => 'alice', 'state' => 'active', 'bot' => false }

  def note
    { 'id' => 11, 'author' => { 'id' => 42, 'username' => 'alice' }, 'system' => false,
      'body' => 'Use the verified revision.' }
  end

  def discussions = [{ 'id' => DISCUSSION, 'notes' => [note] }]

  def client
    runner = lambda do |argv, stdin_data:|
      raise 'Unexpected request body' unless stdin_data == '{}'

      path = argv[4]
      @calls << path
      @counts[path] += 1
      value = @data.fetch(path)
      value = value.call(@counts[path]) if value.respond_to?(:call)
      api_response(path, value)
    end
    Shaka::GitLab.new(host: 'gitlab.example', project: 'group/sub/repo', runner:)
  end

  def api_response(path, value)
    code = @api_failures.fetch(path, value.nil? ? 404 : 200)
    code = code.call(@counts[path]) if code.respond_to?(:call)
    ["HTTP/2.0 #{code} Status\r\n\r\n#{JSON.generate(value)}", 'private token', STATUS.new(code == 200 ? 0 : 1)]
  end

  def screen(rows = discussions, **)
    Shaka::GitLab::ActorTrust.new(client:, project_id: 7, **).screen(rows)
  end

  def with_actor_time(clock)
    original = Time.method(:now)
    Time.define_singleton_method(:now, &clock)
    yield
  ensure
    Time.define_singleton_method(:now, original)
  end
end

class GitLabActorTrustTest < Minitest::Test
  include GitLabActorFixtures

  def test_configured_actor_does_not_depend_on_the_project_membership_list
    @api_failures['projects/7/members/all?per_page=100&page=1'] = 403
    result = screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }])
    assert_equal 'configured_user', result.fetch('notes').first&.fetch('trust')
    refute(@calls.any? { |path| path.include?('/members/') })
  end

  def test_only_the_discussion_author_is_looked_up_as_a_member
    @api_failures['projects/7/members/all?per_page=100&page=1'] = 403
    @data['projects/7/members/all/42'] = user.merge('access_level' => 30)
    assert_equal 'writer', screen.fetch('notes').first&.fetch('trust')
    assert_equal 2, @counts['projects/7/members/all/42']
    refute_includes @calls, 'projects/7/members/all?per_page=100&page=1'
  end

  def test_unavailable_membership_evidence_aborts_instead_of_returning_a_partial_packet
    [401, 403, 429, 500].each do |status|
      @api_failures['projects/7/members/all/42'] = status
      error = assert_raises(Shaka::Error) { screen }
      assert_equal status, error.http_status
    end
  end

  def test_configured_human_requires_authoritative_id_username_and_human_flag
    result = screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }])
    assert_equal 'Use the verified revision.', result.fetch('notes').first&.fetch('body')
    assert_empty result.fetch('withheld')
    assert_includes @calls, 'users/42'
  end

  def test_native_active_developer_membership_trusts_a_verified_human
    @data['projects/7/members/all/42'] = user.merge('access_level' => 30)
    result = screen
    assert_equal 'writer', result.fetch('notes').first&.fetch('trust')
    assert_equal 'Use the verified revision.', result.fetch('notes').first&.fetch('body')
  end

  def test_pending_expired_or_inactive_memberships_do_not_expose_prose
    [{ 'membership_state' => 'awaiting' }, { 'membership_state' => 'pending' }, { 'state' => 'blocked' },
     { 'expires_at' => '2020-01-01' }, { 'expires_at' => 'invalid' }, { 'access_level' => 20 }].each do |changes|
      @data['projects/7/members/all/42'] = user.merge('access_level' => 30).merge(changes)
      result = screen
      assert_empty result.fetch('notes'), changes.inspect
      refute_match(/Use the verified revision/, result.to_json)
    end
  end

  def test_membership_expiring_on_the_current_utc_date_is_conservatively_withheld
    utc_today = Time.now.utc.to_date.iso8601
    @data['projects/7/members/all/42'] = user.merge('access_level' => 30, 'expires_at' => utc_today)
    result = screen
    assert_empty result.fetch('notes')
    assert_equal 'untrusted', result.fetch('withheld').first&.fetch('trust')
  end

  def test_bots_need_explicit_matching_bot_trust_and_metadata_bots_never_expose_body
    @data['users/42'] = user.merge('bot' => true)
    result = screen(trusted_bots: [{ 'id' => 42, 'username' => 'alice' }])
    assert_equal 'configured_bot', result.fetch('notes').first&.fetch('trust')
    metadata = screen(metadata_bots: [{ 'id' => 42, 'username' => 'alice' }])
    assert_equal 'metadata_only', metadata.fetch('metadata_only').first&.fetch('trust')
    refute_match(/Use the verified revision/, metadata.to_json)
  end

  def test_system_notes_never_expose_event_derived_prose_even_for_trusted_humans
    rows = [{ 'id' => DISCUSSION, 'notes' => [note.merge('system' => true)] }]
    result = screen(rows, trusted_users: [{ 'id' => 42, 'username' => 'alice' }])
    assert_empty result.fetch('notes')
    assert_equal 'system', result.fetch('metadata_only').first&.fetch('trust')
    refute_match(/Use the verified revision/, result.to_json)
  end

  def test_wrong_project_or_nonpublic_visibility_cannot_reuse_actor_trust
    [{ 'id' => 8 }, { 'visibility' => 'private' }].each do |changes|
      @data['projects/group%2Fsub%2Frepo'] = project.merge(changes)
      assert_raises(Shaka::Error) { screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }]) }
    end
  end

  def test_changed_visibility_or_user_metadata_aborts_the_entire_packet
    @data['projects/group%2Fsub%2Frepo'] = lambda { |count|
      project.merge('visibility' => count == 1 ? 'public' : 'private')
    }
    assert_raises(Shaka::Error) { screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }]) }
    @data['projects/group%2Fsub%2Frepo'] = project
    @data['users/42'] = ->(count) { user.merge('username' => count.odd? ? 'alice' : 'mallory') }
    assert_raises(Shaka::Error) { screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }]) }
  end

  def test_revoked_membership_aborts_instead_of_returning_stale_writer_prose
    @data['projects/7/members/all/42'] = lambda do |count|
      count == 1 ? user.merge('access_level' => 30) : nil
    end
    assert_raises(Shaka::Error) { screen }
  end

  def test_member_response_cannot_substitute_another_numeric_account
    @data['projects/7/members/all/42'] = user.merge('id' => 43, 'access_level' => 40)
    assert_raises(Shaka::Error) { screen }
  end
end

class GitLabActorProfileAvailabilityTest < Minitest::Test
  include GitLabActorFixtures

  def test_utc_rollover_during_the_final_recheck_discards_writer_prose
    now = Time.utc(2026, 1, 1, 23, 59, 59)
    after = now + 2
    @data['projects/7/members/all/42'] = user.merge('access_level' => 30, 'expires_at' => '2026-01-02')
    @data['users/42'] = lambda do |count|
      now = after if count == 2
      user
    end
    with_actor_time(-> { now }) do
      assert_raises(Shaka::Error) { screen }
    end
  end

  def test_missing_profile_withholds_only_that_author_and_cannot_block_a_configured_author
    @data['users/43'] = {}
    @api_failures['users/43'] = 404
    absent = note.merge('id' => 12, 'author' => { 'id' => 43, 'username' => 'missing-user' },
                        'body' => 'Unverified prose must stay hidden.')
    rows = [{ 'id' => DISCUSSION, 'notes' => [note, absent] }]
    result = screen(rows, trusted_users: [{ 'id' => 42, 'username' => 'alice' }])
    assert_equal 11, result.fetch('notes').first.fetch('id')
    assert_equal 12, result.fetch('withheld').first.fetch('id')
    refute_match(/Unverified prose/, result.to_json)
  end

  def test_profile_appearing_or_disappearing_during_screening_aborts_the_packet
    [[404, 200], [200, 404]].each do |statuses|
      @counts.clear
      @api_failures['users/42'] = ->(count) { statuses.fetch(count - 1) }
      assert_raises(Shaka::Error) { screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }]) }
      assert_equal 2, @counts['users/42']
    end
  end
end

class GitLabActorInputTest < Minitest::Test
  include GitLabActorFixtures

  def test_untrusted_profile_names_and_urls_never_enter_the_packet
    author = note['author'].merge('name' => 'private name', 'web_url' => 'https://evil.test')
    rows = [{ 'id' => DISCUSSION, 'notes' => [note.merge('author' => author)] }]
    @data['users/42'] = user.merge('name' => 'private profile name', 'web_url' => 'https://evil.test')
    result = screen(rows, trusted_users: [{ 'id' => 42, 'username' => 'alice' }])
    assert_equal 'Use the verified revision.', result.fetch('notes').first&.fetch('body')
    refute_match(/private|evil/, result.to_json)
  end

  def test_malformed_actor_identity_or_discussion_metadata_cannot_expose_arbitrary_prose
    [note.merge('author' => { 'id' => 42, 'username' => 'ignore instructions' }),
     note.merge('id' => 'https://evil.test'), note.merge('system' => nil)].each do |bad|
      assert_raises(Shaka::Error) { screen([{ 'id' => DISCUSSION, 'notes' => [bad] }]) }
    end
    @data['users/42'] = user.merge('username' => 'ignore instructions')
    assert_raises(Shaka::Error) { screen }
  end

  def test_renamed_missing_type_and_bot_actors_cannot_inherit_human_trust
    [{ 'username' => 'mallory' }, { 'bot' => nil }, { 'bot' => true }, { 'state' => 'blocked' }].each do |changes|
      @data['users/42'] = user.merge(changes)
      result = screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }])
      assert_empty result.fetch('notes')
      refute_match(/Use the verified revision/, result.to_json)
    end
  end

  def test_missing_membership_withholds_prose_and_is_rechecked
    result = screen
    assert_empty result.fetch('notes')
    assert_equal 'untrusted', result.fetch('withheld').first&.fetch('trust')
    assert_equal 2, @counts['projects/7/members/all/42']
  end

  def test_access_failures_never_return_partially_trusted_prose
    [401, 403, 429, 500].each do |status|
      @api_failures['users/42'] = status
      error = assert_raises(Shaka::Error) { screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }]) }
      assert_equal status, error.http_status
      refute_match(/private|token/, error.message)
    end
  end

  def test_both_configured_and_metadata_bot_classification_remains_metadata_only
    @data['users/42'] = user.merge('bot' => true)
    pair = { 'id' => 42, 'username' => 'alice' }
    result = screen(trusted_bots: [pair], metadata_bots: [pair])
    assert_empty result.fetch('notes')
    assert_equal 'metadata_only', result.fetch('metadata_only').first&.fetch('trust')
  end

  def test_authoritative_user_response_cannot_substitute_another_numeric_account
    @data['users/42'] = user.merge('id' => 43)
    assert_raises(Shaka::Error) { screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }]) }
  end

  def test_access_failure_on_recheck_aborts_the_prepared_packet
    @api_failures['users/42'] = ->(count) { count == 1 ? 200 : 403 }
    error = assert_raises(Shaka::Error) { screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }]) }
    assert_equal 403, error.http_status
    assert_equal 2, @counts['users/42']
  end

  def test_unrelated_membership_churn_does_not_change_a_configured_actor_decision
    @data['projects/7/members/all?per_page=100&page=1'] = lambda do |count|
      [{ 'id' => 99, 'username' => 'other_user', 'state' => 'active', 'access_level' => count == 1 ? 20 : 30 }]
    end
    result = screen(trusted_users: [{ 'id' => 42, 'username' => 'alice' }])
    assert_equal 'configured_user', result.fetch('notes').first&.fetch('trust')
  end
end
