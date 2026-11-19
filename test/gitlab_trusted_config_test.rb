# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/gitlab'
require 'shaka/gitlab/trust_config'

class GitLabTrustedQueryTest < Minitest::Test
  def test_file_ref_is_a_query_parameter_rather_than_a_get_body
    calls = []
    runner = lambda do |argv, stdin_data:|
      calls << [argv, stdin_data]
      ["HTTP/2.0 200 OK\r\n\r\n{\"file_path\":\"policy.yml\"}", '', Struct.new(:exitstatus).new(0)]
    end
    client = Shaka::GitLab.new(host: 'gitlab.example', project: 'group/repo', runner:)
    client.api('projects/7/repository/files/policy.yml', fields: { ref: 'feature+policy' })
    assert_equal 'projects/7/repository/files/policy.yml?ref=feature%2Bpolicy', calls.first.first[4]
    assert_equal({}, JSON.parse(calls.first.last))
  end
end

class GitLabTrustConfigTest < Minitest::Test
  HEAD = 'a' * 40
  PATH = '.agents/shaka/trusted-gitlab-actors.yml'
  POLICY = "trusted_users:\n  - id: 9\n    username: Maintainer\n"
  STATUS = Struct.new(:exitstatus)

  def revision_reads(head: HEAD)
    project = { 'id' => 7, 'path_with_namespace' => 'group/sub/repo', 'visibility' => 'public',
                'web_url' => 'https://gitlab.example/group/sub/repo', 'default_branch' => 'main' }
    branch = { 'name' => 'main', 'default' => true, 'commit' => { 'id' => head } }
    [project, branch, project, branch]
  end

  def file_payload(text = POLICY, **changes)
    { 'file_path' => PATH, 'ref' => HEAD, 'commit_id' => HEAD, 'encoding' => 'base64',
      'size' => text.bytesize, 'content' => [text].pack('m0'),
      'content_sha256' => Digest::SHA256.hexdigest(text) }.merge(changes)
  end

  def loader(*responses)
    @calls = []
    runner = lambda do |argv, stdin_data:|
      @calls << [argv, stdin_data]
      value = responses.shift || raise('Unexpected native request')
      ["HTTP/2.0 200 OK\n\n#{JSON.generate(value)}", '', STATUS.new(0)]
    end
    client = Shaka::GitLab.new(host: 'gitlab.example', project: 'group/sub/repo', runner:)
    Shaka::GitLab::TrustConfig.new(client:)
  end

  def test_trust_pairs_are_read_at_verified_default_commit_with_scoped_provenance
    result = loader(*revision_reads, file_payload, *revision_reads).load
    assert_equal [{ 'id' => 9, 'username' => 'maintainer' }], result.fetch(:users)
    assert_equal({ 'commit' => HEAD, 'host' => 'gitlab.example' }, result.fetch(:sources).first.slice('commit', 'host'))
    assert_equal "projects/7/repository/files/.agents%2Fshaka%2Ftrusted-gitlab-actors.yml?ref=#{HEAD}",
                 @calls[4].first[4]
  end

  def test_changed_default_revision_cannot_return_trust
    assert_raises(Shaka::Error) do
      loader(*revision_reads, file_payload, *revision_reads(head: 'b' * 40)).load
    end
  end

  def test_mismatched_or_corrupt_file_payload_cannot_establish_trust
    [{ 'file_path' => 'other.yml' }, { 'ref' => 'candidate' }, { 'commit_id' => 'b' * 40 },
     { 'encoding' => 'text' }, { 'size' => 0 }, { 'content_sha256' => 'f' * 64 },
     { 'content' => '%%%invalid' }, { 'size' => 100_000 }, { 'content' => nil }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) do
        loader(*revision_reads, file_payload(**changes), *revision_reads).load
      end
    end
  end

  def test_unsafe_ambiguous_or_invalid_actor_settings_are_rejected
    ['--- !ruby/object:Object {}', 'true', 'false', "trusted_users: []\ntrusted_users: []\n",
     'trusted_users: [alice]', 'trusted_groups: [group]',
     'trusted_users: [{id: 9, username: alice}, {id: 9, username: alice}]'].each do |text|
      assert_raises(Shaka::Error, text) { loader(*revision_reads, file_payload(text), *revision_reads).load }
    end
  end
end
