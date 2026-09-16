# frozen_string_literal: true

require 'tmpdir'
require_relative 'comments_fixture'

class CommentTrustConfigTest < Minitest::Test
  include CommentsFixture

  MACHINE = <<~YAML
    trusted_users: [global-maintainer]
    trusted_bots: [review-bot]
    trusted_metadata_bots: [status-bot]
    trusted_teams: [owner/reviewers]
  YAML
  LOCAL = "trusted_users: [repo-maintainer]\ntrusted_teams: [maintainers]\n"

  def with_machine(contents)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'trusted-github-actors.yml')
      File.write(path, contents) if contents
      yield path
    end
  end

  def blob(contents)
    object = contents && { '__typename' => 'Blob', 'text' => contents, 'byteSize' => contents.bytesize,
                           'isBinary' => false, 'isTruncated' => false }
    response({ 'data' => { 'repository' => { 'object' => object } } })
  end

  def test_machine_and_trusted_base_repository_configs_combine
    with_machine(MACHINE) do |path|
      github = client(blob(LOCAL))
      result = Shaka::PublicComments::TrustConfig.new(github, machine_path: path).load(base_oid: HEAD)
      assert_combined_actors(result)
      assert_config_provenance(result)
    end
  end

  def assert_combined_actors(result)
    assert_equal Set['global-maintainer', 'repo-maintainer'], result[:users]
    assert_equal Set['review-bot'], result[:bots]
    assert_equal Set['status-bot'], result[:metadata_bots]
    assert_equal [%w[owner reviewers], %w[owner maintainers]], result[:teams]
  end

  def assert_config_provenance(result)
    assert_equal(%w[machine repository], result[:sources].map { |source| source['scope'] })
    assert_equal "#{HEAD}:.agents/trusted-github-actors.yml",
                 JSON.parse(@calls.first.last).dig('variables', 'expression')
  end

  def test_absent_configs_are_empty_without_reading_candidate_checkout
    with_machine(nil) do |path|
      result = Shaka::PublicComments::TrustConfig.new(client(blob(nil)), machine_path: path).load(base_oid: HEAD)

      assert_empty result[:users]
      assert_empty result[:teams]
      assert_empty result[:sources]
      assert_equal 1, @calls.length
    end
  end

  def test_invalid_machine_yaml_fails_closed_before_api_lookup
    with_machine("trusted_users: !ruby/object:Object {}\n") do |path|
      error = assert_raises(Shaka::Error) do
        Shaka::PublicComments::TrustConfig.new(client, machine_path: path).load(base_oid: HEAD)
      end

      assert_match(/unsafe YAML/, error.message)
      assert_empty @calls
    end
  end

  def test_truncated_repository_config_is_not_treated_as_absent
    object = { '__typename' => 'Blob', 'text' => 'trusted_users: [outside]', 'byteSize' => 24,
               'isBinary' => false, 'isTruncated' => true }
    with_machine(nil) do |path|
      github = client(response({ 'data' => { 'repository' => { 'object' => object } } }))
      error = assert_raises(Shaka::Error) do
        Shaka::PublicComments::TrustConfig.new(github, machine_path: path).load(base_oid: HEAD)
      end

      assert_match(/not readable text/, error.message)
    end
  end

  def test_conflicting_bot_scopes_cannot_promote_metadata_bot
    with_machine("trusted_metadata_bots: [review-bot]\n") do |path|
      error = assert_raises(Shaka::Error) do
        Shaka::PublicComments::TrustConfig.new(client(blob("trusted_bots: [review-bot]\n")), machine_path: path)
                                          .load(base_oid: HEAD)
      end

      assert_match(/metadata-only/, error.message)
    end
  end

  def test_machine_team_requires_owner
    with_machine("trusted_teams: [reviewers]\n") do |path|
      error = assert_raises(Shaka::Error) do
        Shaka::PublicComments::TrustConfig.new(client, machine_path: path).load(base_oid: HEAD)
      end
      assert_match(/Machine teams need/, error.message)
    end
  end

  def test_repo_team_cannot_cross_owner
    with_machine(nil) do |path|
      error = assert_raises(Shaka::Error) do
        Shaka::PublicComments::TrustConfig.new(client(blob("trusted_teams: [other/reviewers]\n")), machine_path: path)
                                          .load(base_oid: HEAD)
      end
      assert_match(/must match repository owner/, error.message)
    end
  end

  def test_issue_base_is_a_pinned_default_branch_commit
    ref = { 'defaultBranchRef' => { 'target' => { 'oid' => HEAD } } }
    github = client(response({ 'data' => { 'repository' => ref } }))
    assert_equal HEAD, Shaka::PublicComments::TrustConfig.new(github).default_base_oid
  end
end
