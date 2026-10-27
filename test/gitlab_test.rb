# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/gitlab'

class GitLabTest < Minitest::Test
  STATUS = Struct.new(:exitstatus)

  def client(*values)
    @calls = []
    runner = lambda do |argv, stdin_data:|
      @calls << [argv, stdin_data]
      ["HTTP/2.0 200 OK\nContent-Type: application/json\n\n#{JSON.generate(values.shift)}", '', STATUS.new(0)]
    end
    Shaka::GitLab.new(host: 'gitlab.example:8443', project: 'group/sub/project', runner:)
  end

  def project_info(**changes)
    { 'id' => 7, 'path_with_namespace' => 'group/sub/project',
      'web_url' => 'https://gitlab.example:8443/group/sub/project', 'default_branch' => 'release/main',
      'visibility' => 'private', 'permissions' => { 'project_access' => { 'access_level' => 50 } } }.merge(changes)
  end

  def test_project_preserves_native_identity_and_permissions_for_nested_namespaces
    info = project_info
    assert_equal info, client(info).project
    assert_equal 'projects/group%2Fsub%2Fproject', @calls.first.first[4]
  end

  def test_redirected_or_malformed_project_metadata_cannot_establish_identity
    [{ 'id' => 0 }, { 'id' => '7' }, { 'path_with_namespace' => 'other/project' },
     { 'web_url' => 'https://other.example/group/sub/project' },
     { 'web_url' => 'https://gitlab.example/group/sub/project' },
     { 'visibility' => nil }, { 'default_branch' => nil }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) { client(project_info(**changes)).project }
    end
  end

  def branch_info(**changes)
    { 'name' => 'release/main', 'default' => true, 'commit' => { 'id' => 'a' * 40 } }.merge(changes)
  end

  def test_default_revision_pins_native_branch_commit_between_stable_project_reads
    result = client(project_info, branch_info, project_info, branch_info).default_revision
    assert_equal 'a' * 40, result.fetch('sha')
    assert_equal 'release/main', result.fetch('default_branch')
    assert_equal 'gitlab.example:8443', result.fetch('host')
    assert_equal(['projects/group%2Fsub%2Fproject', 'projects/7/repository/branches/release%2Fmain',
                  'projects/group%2Fsub%2Fproject', 'projects/7/repository/branches/release%2Fmain'],
                 @calls.map { |argv, _| argv[4] })
  end

  def test_default_revision_rejects_head_branch_and_project_changes
    [{ 'id' => 8 }, { 'default_branch' => 'other' }].each do |changes|
      assert_raises(Shaka::Error) do
        client(project_info, branch_info, project_info(**changes), branch_info).default_revision
      end
    end
  end

  def test_default_revision_rejects_invalid_branch_or_head_changes
    [{ 'commit' => { 'id' => 'b' * 40 } }, { 'name' => 'other' }, { 'default' => false },
     { 'commit' => nil }, { 'commit' => { 'id' => 'bad-sha' } }].each do |changes|
      assert_raises(Shaka::Error, changes.inspect) do
        client(project_info, branch_info, project_info, branch_info(**changes)).default_revision
      end
    end
  end

  def test_default_revision_accepts_url_encoded_valid_branch_names
    { 'release+stable' => 'release%2Bstable', 'développement' => 'd%C3%A9veloppement' }.each do |name, encoded|
      info = project_info('default_branch' => name)
      branch = branch_info('name' => name)
      assert_equal 'a' * 40, client(info, branch, info, branch).default_revision.fetch('sha')
      assert_equal "projects/7/repository/branches/#{encoded}", @calls[1].first[4]
    end
  end

  def test_api_uses_explicit_host_and_json_stdin_without_shell_interpolation
    instance = client({ 'id' => 7 })
    body = 'Text $(touch /tmp/unsafe), `commands`, @files and é.'
    result = instance.api('projects/7/notes', method: 'POST', fields: { body: })
    assert_equal({ 'id' => 7 }, result)
    assert_equal ['glab', 'api', '--hostname', 'gitlab.example:8443', 'projects/7/notes',
                  '--method', 'POST', '--include', '--input', '-'], @calls.first.first
    assert_equal({ 'body' => body }, JSON.parse(@calls.first.last))
  end
end
