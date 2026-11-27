# frozen_string_literal: true

require_relative 'throughput_helper'
require 'yaml'
require 'shaka/pr_watch/stats_command'

# After a GitHub merge click, pr stats fills the times no watcher recorded, and the workflow runs it safely.
class PrStatsTest < Minitest::Test
  include ThroughputHelper

  Seam = Struct.new(:merge, :review)
  SEAM = Seam.new({}, { 'ci_review_jobs' => [], 'ci_review_wait' => 'none' })
  WORKFLOW = File.expand_path('../.github/workflows/pr-stats.yml', __dir__)

  def test_a_merged_pull_request_gets_its_ready_and_merge_times
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    result = Shaka::PrWatch::StatsCommand.record(github, SEAM)

    assert_equal 2, github.patches.size
    assert_includes github.patches.last, 'CI to ready 41m · Ready to merged 2h 5m'
    assert_equal({ 't2' => READY.iso8601, 't3' => MERGED.iso8601 }, result['stats'].slice('t2', 't3'))
  end

  def test_a_second_run_writes_nothing
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    Shaka::PrWatch::StatsCommand.record(github, SEAM)
    Shaka::PrWatch::StatsCommand.record(github, SEAM)
    assert_equal 2, github.patches.size
  end

  def test_a_pull_request_without_a_stats_block_is_not_written
    github = MergedFakeGitHub.new("Written by hand.\n", merged_page)
    assert_nil Shaka::PrWatch::StatsCommand.record(github, SEAM)['stats']
    assert_empty github.patches
  end

  def test_the_command_refuses_to_run_without_a_trusted_ref
    _, err = capture_io { assert_equal 1, Shaka::PrWatch::StatsCommand.run(%w[owner/repo 7]) }
    assert_includes err, '--ref SHA'
  end

  def test_the_workflow_runs_only_after_a_merge_into_the_default_branch
    workflow = YAML.load_file(WORKFLOW)
    job = workflow.dig('jobs', 'stats')

    assert_equal ['closed'], (workflow['on'] || workflow[true]).dig('pull_request_target', 'types')
    assert_includes job['if'], 'github.event.pull_request.merged == true'
    assert_includes job['if'], 'base.ref == github.event.repository.default_branch'
    assert_equal({}, workflow['permissions'])
    assert_equal({ 'contents' => 'read', 'pull-requests' => 'write' }, job['permissions'])
  end

  def test_the_workflow_never_runs_pull_request_code_or_text
    steps = YAML.load_file(WORKFLOW).dig('jobs', 'stats', 'steps')
    checkout = steps.first

    refute checkout.fetch('with').key?('ref'), 'the job must not check out the pull request head'
    refute checkout.dig('with', 'persist-credentials')
    refute_match(/\$\{\{/, steps.last['run'])
  end

  def test_the_workflow_pins_every_action_to_a_commit
    steps = YAML.load_file(WORKFLOW).dig('jobs', 'stats', 'steps')
    assert(steps.all? { |step| !step['uses'] || step['uses'].match?(/@[0-9a-f]{40}\b/) })
  end

  private

  def unready_block = describe('$4.12', timeline: push_times, pull: head_pull)

  def merged_page
    { 'headRefOid' => HEAD, 'mergedAt' => MERGED.iso8601,
      'commits' => { 'nodes' => [{ 'commit' => gql(HEAD, PUSH.iso8601, []) }] } }
  end
end

# A pull request GitHub merged after its required check passed, with nothing recorded since publication.
class MergedFakeGitHub < ThroughputFakeGitHub
  def initialize(body, pull)
    super(body, pull, [{ 'name' => 'validate', 'bucket' => 'pass', 'completedAt' => ThroughputHelper::READY.iso8601 }])
  end

  def snapshot = { 'headRefOid' => ThroughputHelper::HEAD, 'state' => 'MERGED', 'baseRefName' => 'main' }
  def required_checks = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
  def configured_required_checks = []
  def checks = required_checks
end
