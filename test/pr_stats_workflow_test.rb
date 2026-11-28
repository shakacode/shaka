# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

# The pr stats workflow runs only the default branch's code, after a merge into it, with a narrow token.
class PrStatsWorkflowTest < Minitest::Test
  WORKFLOW = File.expand_path('../.github/workflows/pr-stats.yml', __dir__)
  CONDITION = 'github.event.pull_request.merged == true && ' \
              'github.event.pull_request.base.ref == github.event.repository.default_branch'

  def test_the_workflow_runs_only_after_a_merge_into_the_default_branch
    workflow = YAML.load_file(WORKFLOW)
    job = workflow.dig('jobs', 'stats')

    assert_equal ['closed'], (workflow['on'] || workflow[true]).dig('pull_request_target', 'types')
    assert_equal CONDITION, job['if']
    assert_equal({}, workflow['permissions'])
    assert_equal({ 'checks' => 'read', 'contents' => 'read', 'pull-requests' => 'write', 'statuses' => 'read' },
                 job['permissions'])
  end

  def test_the_workflow_never_runs_pull_request_code_or_text
    steps = YAML.load_file(WORKFLOW).dig('jobs', 'stats', 'steps')

    assert_equal 3, steps.size
    refute steps.first.fetch('with').key?('ref'), 'the job must not check out the pull request head'
    refute steps.first.dig('with', 'persist-credentials')
    refute_match(/\$\{\{/, steps.last['run'])
  end

  def test_the_workflow_pins_every_action_to_a_commit
    steps = YAML.load_file(WORKFLOW).dig('jobs', 'stats', 'steps')
    assert(steps.all? { |step| !step['uses'] || step['uses'].match?(/@[0-9a-f]{40}\b/) })
  end
end
