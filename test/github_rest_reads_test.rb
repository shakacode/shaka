# frozen_string_literal: true

require_relative 'github_helper'

class GitHubRestReadsTest < Minitest::Test
  include GitHubHelper

  def test_snapshot_maps_the_rest_pull_to_the_graphql_field_names
    snapshot = client(response(rest_pull.merge('labels' => [{ 'name' => 'hold' }]))).rest_snapshot

    assert_equal %w[OPEN BLOCKED rest], snapshot.values_at('state', 'mergeStateStatus', 'readOver')
    assert_equal [HEAD, 'main', false, nil], snapshot.values_at('headRefOid', 'baseRefName', 'merged', 'mergeCommit')
    assert_equal({ 'totalCount' => 1, 'nodes' => [{ 'name' => 'hold' }] }, snapshot['labels'])
  end

  def test_snapshot_names_the_fields_rest_cannot_read_instead_of_reporting_them
    snapshot = client(response(rest_pull.merge('auto_merge' => { 'merge_method' => 'squash' }))).rest_snapshot

    %w[reviewDecision viewerCanMergeAsAdmin isInMergeQueue mergeQueueEntry].each do |field|
      refute snapshot.key?(field), "#{field} must be absent, not false or empty"
      assert_includes snapshot['unknownFields'], field
    end
    assert_includes snapshot['unknownFields'], 'autoMergeRequest.enabledAt'
  end

  # REST names a test merge in merge_commit_sha before merge; only a merged PR has a merge commit.
  def test_a_merged_pull_reports_its_merge_commit
    snapshot = client(response(rest_pull.merge('state' => 'closed', 'merged' => true))).rest_snapshot

    assert_equal ['MERGED', { 'oid' => BASE }], snapshot.values_at('state', 'mergeCommit')
  end

  def test_a_response_for_another_pull_is_refused
    error = assert_raises(Shaka::Error) { client(response(rest_pull.merge('number' => 7))).rest_snapshot }
    assert_includes error.message, 'requested pull request'
  end

  def test_checks_shape_check_runs_and_statuses_like_gh_pr_checks
    runs = [check_run('validate', 'completed', 'success'), check_run('lint', 'in_progress', nil),
            check_run('docs', 'completed', 'skipped'), check_run('deploy', 'completed', 'startup_failure')]
    statuses = [{ 'context' => 'ci/legacy', 'state' => 'failure', 'target_url' => 'https://ci.example/1' }]
    rows = client(runs_page(runs), status_page(statuses)).rest_checks(HEAD)

    assert_equal([%w[validate SUCCESS pass], %w[lint IN_PROGRESS pending], %w[docs SKIPPED skipping],
                  %w[deploy STARTUP_FAILURE fail], %w[ci/legacy FAILURE fail]],
                 rows.map { |row| row.values_at('name', 'state', 'bucket') })
    assert_equal "repos/owner/repo/commits/#{HEAD}/check-runs?per_page=100&page=1", @calls.first.first[2]
  end

  def test_checks_read_every_page
    rows = client(runs_page(full_page, total: 101), runs_page([check_run('last', 'queued', nil)], total: 101),
                  status_page([])).rest_checks(HEAD)
    assert_equal 101, rows.size
  end

  def test_checks_refuse_a_truncated_set
    error = assert_raises(Shaka::Error) { client(*Array.new(10) { runs_page(full_page, total: 5000) }).rest_checks(HEAD) }
    assert_includes error.message, 'truncated'
  end

  # Mirrors the predecessor's exact-head binding: evidence for another commit never counts for this head.
  def test_checks_for_another_commit_are_refused
    stale = check_run('validate', 'completed', 'success').merge('head_sha' => BASE)
    assert_raises(Shaka::Error) { client(runs_page([stale])).rest_checks(HEAD) }

    other = response({ 'sha' => BASE, 'total_count' => 0, 'statuses' => [] })
    assert_raises(Shaka::Error) { client(runs_page([]), other).rest_checks(HEAD) }
  end

  def test_configured_checks_combine_classic_protection_and_rulesets
    github = client(branch_response(%w[ci validate]), rules_response('validate'))

    assert_equal %w[ci validate], github.rest_configured_required_checks('main')
    assert_equal 'repos/owner/repo/branches/main', @calls.first.first[2]
  end

  def test_an_unprotected_branch_requires_nothing_classic
    github = client(response({ 'protected' => false }), response([]))
    assert_empty github.rest_configured_required_checks('main')
  end

  def test_unreadable_classic_protection_is_refused_rather_than_read_as_empty
    [{ 'protected' => true }, { 'protected' => true, 'protection' => { 'required_status_checks' => {} } }].each do |b|
      error = assert_raises(Shaka::Error) { client(response(b)).rest_configured_required_checks('main') }
      assert_includes error.message, 'branch protection'
    end
  end

  def test_the_rest_view_requires_only_configured_checks_and_reads_each_list_once
    view = view_requiring_validate(check_run('validate', 'completed', 'failure'),
                                   check_run('optional', 'completed', 'success'))
    view.snapshot

    2.times { assert_equal(%w[validate], view.required_checks.map { it['name'] }) }
    assert_equal 5, @calls.size
  end

  private

  def rest_pull
    { 'number' => 42, 'node_id' => 'PR_1', 'html_url' => 'https://github.com/owner/repo/pull/42', 'state' => 'open',
      'draft' => false, 'merged' => false, 'merge_commit_sha' => BASE, 'mergeable_state' => 'blocked',
      'user' => { 'login' => 'octocat' }, 'auto_merge' => nil, 'labels' => [],
      'head' => { 'sha' => HEAD, 'repo' => { 'full_name' => 'owner/repo' } },
      'base' => { 'ref' => 'main', 'repo' => { 'full_name' => 'owner/repo' } },
      'changed_files' => 2, 'additions' => 10, 'deletions' => 3, 'commits' => 1 }
  end

  def check_run(name, status, conclusion)
    { 'name' => name, 'status' => status, 'conclusion' => conclusion, 'head_sha' => HEAD,
      'details_url' => "https://ci.example/#{name}" }
  end

  def full_page = Array.new(100) { |index| check_run("job-#{index}", 'completed', 'success') }

  def runs_page(runs, total: runs.size) = response({ 'total_count' => total, 'check_runs' => runs })

  def status_page(statuses) = response({ 'sha' => HEAD, 'total_count' => statuses.size, 'statuses' => statuses })

  def branch_response(contexts)
    response({ 'protected' => true, 'protection' => { 'required_status_checks' => { 'contexts' => contexts } } })
  end

  def view_requiring_validate(*runs)
    client(response(rest_pull), runs_page(runs), status_page([]), branch_response([]),
           rules_response('validate')).over_rest
  end

  def rules_response(*contexts)
    checks = contexts.map { |context| { 'context' => context } }
    response([{ 'type' => 'required_status_checks', 'parameters' => { 'required_status_checks' => checks } }])
  end
end
