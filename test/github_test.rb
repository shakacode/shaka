# frozen_string_literal: true

require_relative 'github_helper'

class GitHubTest < Minitest::Test
  include GitHubHelper

  def test_snapshot_uses_native_graphql_variables
    result = client(snapshot_response).snapshot
    assert_equal HEAD, result['headRefOid']
    assert_equal %w[gh api graphql --method POST --input -], @calls.first.first
    assert_equal({ 'owner' => 'owner', 'name' => 'repo', 'number' => 42 }, JSON.parse(@calls.first.last)['variables'])
  end

  def test_api_passes_body_as_json_without_shell_interpolation
    body = 'Text with $(touch /tmp/unsafe), `commands`, "quotes", @files and é.'
    client(response({ 'ok' => true })).api('repos/owner/repo', method: 'POST', fields: { body: body })
    assert_equal %w[gh api repos/owner/repo --method POST --input -], @calls.first.first
    assert_equal({ 'body' => body }, JSON.parse(@calls.first.last))
  end

  def test_checks_preserve_pending_and_failure_states_including_nonzero_exit
    [0, 1, 8].each do |exitstatus|
      checks = [{ 'state' => 'FAILURE', 'bucket' => 'fail' }, { 'state' => 'PENDING', 'bucket' => 'pending' }]
      assert_equal checks, client(response(checks, status: exitstatus)).required_checks
      assert_equal ['gh', 'pr', 'checks', '42', '--repo', 'owner/repo', '--required', '--json',
                    'name,state,bucket,link'], @calls.first.first
    end
  end

  def test_api_failure_does_not_expose_stderr
    error = assert_raises(Shaka::Error) { client(response({}, status: 4)).snapshot }
    assert_match(/exit 4/, error.message)
    refute_match(/private/, error.message)
  end

  def test_malformed_json_and_utf8_are_domain_errors
    ['broken JSON', "\xff".b].each do |raw|
      assert_raises(Shaka::Error) { client([raw, '', STATUS.new(0)]).snapshot }
    end
  end

  def test_missing_or_denied_graphql_data_is_not_a_snapshot
    [{ 'errors' => [{ 'message' => 'unauthorized' }] }, { 'data' => {} },
     { 'data' => { 'repository' => nil } }, { 'data' => { 'repository' => 'malformed' } }, []].each do |value|
      assert_raises(Shaka::Error) { client(response(value)).snapshot }
    end
  end

  def test_checks_require_an_array
    assert_raises(Shaka::Error) { client(response({ 'message' => 'error' })).required_checks }
  end

  def test_checks_with_empty_failed_output_report_unavailable_evidence
    error = assert_raises(Shaka::Error) do
      client(['', 'no required checks reported', STATUS.new(1)]).required_checks
    end
    assert_match(/Required-check evidence is unavailable/, error.message)
  end

  def test_repository_and_identifier_are_validated_before_execution
    ['owner/repo;whoami', '--repo', 'owner/..', 'https://github.com/owner/repo', "\xff", nil].each do |repository|
      assert_raises(Shaka::Error) { Shaka::GitHub.new(repository, 42) }
    end
    [0, -1, '42x', '--help', "\xff", nil].each do |number|
      assert_raises(Shaka::Error) { Shaka::GitHub.new('owner/repo', number) }
    end
  end

  def test_missing_cli_is_an_actionable_error
    runner = ->(*) { raise Errno::ENOENT }
    error = assert_raises(Shaka::Error) do
      Shaka::GitHub.new('owner/repo', 42, runner: runner).snapshot
    end
    assert_match(/install gh/, error.message)
  end
end
