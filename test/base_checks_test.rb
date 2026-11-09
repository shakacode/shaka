# frozen_string_literal: true

require_relative 'github_helper'
require 'shaka/base_checks'
require 'shaka/status'

# `shaka pr` shows how each failing head check ended on the base branch, so the agent compares
# logs before repairing a failure the base already has.
class BaseChecksTest < Minitest::Test
  BASE_SHA = 'b' * 40

  # Answers the two base reads BaseChecks makes and records them.
  class Base
    attr_reader :reads

    def initialize(rows)
      @rows = rows
      @reads = []
    end

    def branch_tip(branch)
      @reads << [:tip, branch]
      BASE_SHA
    end

    def rest_checks(sha)
      @reads << [:checks, sha]
      @rows
    end
  end

  def test_a_green_head_reads_nothing_from_the_base
    base = Base.new([])

    assert_empty Shaka::BaseChecks.new(base).call('main', [row('lint', 'pass'), row('docs', 'pending')], [])
    assert_empty base.reads
  end

  def test_reports_each_failing_check_beside_its_base_result
    base = Base.new([row('lint', 'fail', 'https://ci/base-lint'), row('unit', 'pass')])
    head = [row('lint', 'fail'), row('unit', 'fail'), row('e2e', 'fail'), row('docs', 'pass')]

    report = Shaka::BaseChecks.new(base).call('main', head, ['unit'])['baseChecks']

    assert_equal ['main', BASE_SHA], report.values_at('baseRefName', 'baseSha')
    assert_equal [['lint', false, 'fail', 'https://ci/base-lint'], ['unit', true, 'pass', 'https://ci/unit'],
                  ['e2e', false, 'missing', nil]], summary(report, 'name', 'required', 'base', 'baseLink')
    assert_equal [[:tip, 'main'], [:checks, BASE_SHA]], base.reads
  end

  # Two base rows with one name that disagree are not evidence that the base fails that check.
  def test_disagreeing_base_rows_are_mixed
    report = Shaka::BaseChecks.new(Base.new([row('lint', 'fail'), row('lint', 'pass')]))
                              .call('main', [row('lint', 'fail')], nil)['baseChecks']

    assert_equal [[nil, 'mixed']], summary(report, 'required', 'base')
  end

  def test_refuses_a_missing_base_branch
    error = assert_raises(Shaka::Error) { Shaka::BaseChecks.new(Base.new([])).call(nil, [row('lint', 'fail')], []) }

    assert_match(/base branch/, error.message)
  end

  private

  def row(name, bucket, link = "https://ci/#{name}") = { 'name' => name, 'bucket' => bucket, 'link' => link }

  def summary(report, *keys) = report['failing'].map { |entry| entry.values_at(*keys) }
end

# Status adds the comparison only for `shaka pr`, reading the base tip over REST.
class StatusBaseChecksTest < Minitest::Test
  include GitHubHelper

  VALIDATE = { 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }.freeze
  LINT = { 'name' => 'lint', 'state' => 'FAILURE', 'bucket' => 'fail', 'link' => 'https://ci/head' }.freeze

  def test_reports_a_failing_check_beside_its_base_result
    base_run = { 'name' => 'lint', 'status' => 'completed', 'conclusion' => 'failure', 'head_sha' => BASE,
                 'details_url' => 'https://ci/base' }
    result = status(response({ 'commit' => { 'sha' => BASE } }),
                    response({ 'total_count' => 1, 'check_runs' => [base_run] }),
                    response({ 'sha' => BASE, 'total_count' => 0, 'statuses' => [] }))

    assert_equal({ 'baseRefName' => 'main', 'baseSha' => BASE,
                   'failing' => [{ 'name' => 'lint', 'required' => false, 'link' => 'https://ci/head',
                                   'base' => 'fail', 'baseLink' => 'https://ci/base' }] }, result['baseChecks'])
    assert_equal %w[gh api repos/owner/repo/branches/main], @calls[6][0].first(3)
  end

  def test_reports_an_unreadable_base_without_failing
    result = status(response({}, status: 1, http_status: 404))

    assert_equal [VALIDATE], result['requiredChecks']
    assert_includes result['baseChecksUnavailable'], 'branches/main'
  end

  private

  # Snapshot, required checks, branch rules, snapshot again, then every head check and the base reads.
  def status(*base_reads)
    snapshot = response({ 'data' => { 'repository' => { 'pullRequest' => {
                          'headRefOid' => HEAD, 'state' => 'OPEN', 'baseRefName' => 'main'
                        } } } })
    github = client(snapshot, response([VALIDATE]), *no_configured_requirements, snapshot,
                    response([VALIDATE, LINT], status: 1), *base_reads)
    Shaka::Status.new(github, base_checks: true).call
  end
end
