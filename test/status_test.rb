# frozen_string_literal: true

require_relative 'github_helper'
require 'shaka/status'

class StatusTest < Minitest::Test
  include GitHubHelper

  def test_status_reports_the_snapshot_with_required_check_states
    checks = [{ 'name' => 'validate', 'state' => 'PENDING', 'bucket' => 'pending' }]
    result = Shaka::Status.new(client(snapshot_response, response(checks, status: 8), *no_configured_requirements,
                                      snapshot_response)).call
    assert_equal HEAD, result['headRefOid']
    assert_equal checks, result['requiredChecks']
    assert_equal 'github', result['requiredChecksSource']
  end

  def test_status_reports_seam_required_checks_when_github_enforces_none
    empty = ['', "no required checks reported on the 'main' branch\n", STATUS.new(1)]
    head = [{ 'name' => 'checks', 'state' => 'SUCCESS', 'bucket' => 'pass' },
            { 'name' => 'lint', 'state' => 'PENDING', 'bucket' => 'pending' }]
    github = client(snapshot_response, empty, *no_configured_requirements, response(head, status: 8), snapshot_response)
    result = Shaka::Status.new(github, seam_required_checks: ['checks']).call

    assert_equal [head.first], result['requiredChecks']
    assert_equal 'seam', result['requiredChecksSource']
  end

  def test_status_reports_absent_required_checks_without_failing
    empty = ['', "no required checks reported on the 'main' branch\n", STATUS.new(1)]
    result = Shaka::Status.new(client(snapshot_response, empty, *no_configured_requirements, snapshot_response)).call
    assert_equal [], result['requiredChecks']
    refute result.key?('requiredChecksUnavailable')
  end

  def test_status_reports_unavailable_required_checks_without_failing
    unavailable = ['', 'no required checks reported', STATUS.new(1)]
    result = Shaka::Status.new(client(snapshot_response, unavailable, snapshot_response)).call
    assert_nil result['requiredChecks']
    assert_includes result['requiredChecksUnavailable'], 'unavailable'
  end

  # Branch rules are read even beside reported checks, so an unreadable rule set cannot pass the gate.
  def test_status_reports_unreadable_branch_rules_as_unavailable
    checks = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
    github = client(snapshot_response, response(checks), response({}, status: 1), snapshot_response)
    result = Shaka::Status.new(github).call
    assert_nil result['requiredChecks']
    assert result.key?('requiredChecksUnavailable')
  end

  def test_status_rejects_a_head_that_changed_while_reading
    checks = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
    status = Shaka::Status.new(client(snapshot_response, response(checks), *no_configured_requirements,
                                      snapshot_response(head: 'b' * 40)))
    error = assert_raises(Shaka::Error) { status.call }
    assert_includes error.message, 'head changed'
  end

  # The first line `gh api graphql` printed in a Claude Code cloud session, trimmed before the proxy's route list.
  REFUSED = ['{"message":"GitHub GraphQL is not available from Claude Code sessions"}',
             'gh: GitHub GraphQL is not available from Claude Code sessions; use the REST API. (HTTP 403)',
             STATUS.new(1)].freeze

  def test_a_graphql_refusal_reads_the_pull_and_required_checks_over_rest
    validate = { 'name' => 'validate', 'status' => 'completed', 'conclusion' => 'success', 'head_sha' => HEAD }
    result = Shaka::Status.new(client(REFUSED, *rest_reads([validate], required: 'validate')), rest_fallback: true).call

    assert_equal [HEAD, 'rest', 'github'], result.values_at('headRefOid', 'readOver', 'requiredChecksSource')
    assert_equal([%w[validate pass]], result['requiredChecks'].map { it.values_at('name', 'bucket') })
    assert_includes result['unknownFields'], 'reviewDecision'
    refute result.key?('reviewDecision')
  end

  # Only `shaka pr` asks for the fallback; other commands keep the GraphQL failure.
  def test_a_graphql_refusal_without_the_fallback_keeps_its_error
    error = assert_raises(Shaka::GraphqlRefused) { Shaka::Status.new(client(REFUSED)).call }
    assert_equal 403, error.http_status
  end

  def test_other_graphql_failures_do_not_fall_back_to_rest
    [response({}, status: 1, http_status: 502), response({ 'errors' => [{}] })].each do |failure|
      error = assert_raises(Shaka::Error) { Shaka::Status.new(client(failure), rest_fallback: true).call }
      refute_kind_of Shaka::GraphqlRefused, error
      assert_equal 1, @calls.size
    end
  end

  def test_a_refusal_from_rest_itself_is_not_read_as_a_graphql_refusal
    refute Shaka::GraphqlRefused.refusal?('gh: Resource not accessible by integration (HTTP 403)')
    assert Shaka::GraphqlRefused.refusal?('gh: refused (HTTP 403)', graphql_request: true)
    assert Shaka::GraphqlRefused.refusal?('HTTP 403: refused (https://api.github.com/graphql)')
    refute Shaka::GraphqlRefused.refusal?('gh: Bad gateway (HTTP 502)', graphql_request: true)
  end

  private

  def rest_pull
    response({ 'number' => 42, 'state' => 'open', 'merged' => false, 'mergeable_state' => 'clean',
               'head' => { 'sha' => HEAD }, 'base' => { 'ref' => 'main' } })
  end

  # The REST reads Status makes, in order: pull, check runs, statuses, branch, rulesets, pull again.
  def rest_reads(runs, required:)
    rules = [{ 'type' => 'required_status_checks',
               'parameters' => { 'required_status_checks' => [{ 'context' => required }] } }]
    [rest_pull, response({ 'total_count' => runs.size, 'check_runs' => runs }),
     response({ 'sha' => HEAD, 'total_count' => 0, 'statuses' => [] }), response({ 'protected' => false }),
     response(rules), rest_pull]
  end
end
