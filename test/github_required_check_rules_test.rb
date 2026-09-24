# frozen_string_literal: true

require_relative 'github_helper'

class GitHubRequiredCheckRulesTest < Minitest::Test
  include GitHubHelper

  PLAN_403 = ['{"message":"Upgrade to GitHub Pro or make this repository public to enable this feature."}',
              'gh: Upgrade to GitHub Pro or make this repository public to enable this feature. (HTTP 403)',
              STATUS.new(1)].freeze

  def test_reports_classic_protection_and_ruleset_contexts
    rules = [{ 'type' => 'pull_request' },
             { 'type' => 'required_status_checks',
               'parameters' => { 'required_status_checks' => [{ 'context' => 'validate' }] } }]
    github = client(base_rule_response(['ci']), response(rules))

    assert_equal %w[ci validate], github.configured_required_checks
    assert_equal ['gh', 'api', 'repos/owner/repo/rules/branches/main?per_page=100'], @calls.last.first.first(3)
  end

  def test_an_unprotected_branch_requires_nothing
    assert_empty client(base_rule_response(nil), response([])).configured_required_checks
  end

  def test_a_plan_without_rulesets_requires_nothing_beyond_classic_protection
    assert_empty client(base_rule_response([]), PLAN_403).configured_required_checks
  end

  def test_other_ruleset_failures_are_not_treated_as_no_requirements
    forbidden = ['{"message":"Resource not accessible"}', 'gh: Resource not accessible (HTTP 403)', STATUS.new(1)]
    github = client(base_rule_response([]), forbidden)

    error = assert_raises(Shaka::Error) { github.configured_required_checks }
    assert_equal 403, error.http_status
  end

  def test_a_full_page_of_rules_is_refused_rather_than_truncated
    rules = Array.new(100) { { 'type' => 'pull_request' } }
    error = assert_raises(Shaka::Error) { client(base_rule_response([]), response(rules)).configured_required_checks }
    assert_includes error.message, 'rules'
  end

  private

  def base_rule_response(contexts)
    rule = contexts && { 'requiredStatusCheckContexts' => contexts }
    response({ 'data' => { 'repository' => { 'pullRequest' => {
               'baseRefName' => 'main', 'baseRef' => { 'refUpdateRule' => rule }
             } } } })
  end
end
