# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/pr_watch'

# Times, descriptions, and GitHub check history shared by the throughput tests.
module ThroughputHelper
  HEAD = 'a' * 40
  NEXT = 'b' * 40
  LATER = Time.utc(2026, 10, 26, 20, 0, 0)
  START = Time.utc(2026, 10, 26, 18, 0, 0)
  PUSH = Time.utc(2026, 10, 26, 18, 38, 0)
  READY = Time.utc(2026, 10, 26, 19, 19, 0)
  MERGED = Time.utc(2026, 10, 26, 21, 24, 0)

  private

  def filled_block
    first = describe('$4.12', timeline: push_times, pull: head_pull)
    Shaka::ThroughputStats.update(first, 't2' => READY.iso8601, 'head' => HEAD)
  end

  def head_pull = { 'head' => { 'sha' => HEAD } }
  def push_times = { 'task_started_at' => START, 'ci_started_at' => PUSH }

  def describe(usd = 'UNKNOWN', timeline: nil, pull: nil)
    full = { 'opened' => START, 'labels' => [] }.merge(timeline || {})
    Shaka::Publication.description(content(usd), nil, pull, nil, full)
  end

  def content(usd = 'UNKNOWN')
    column = PublicationRegressionTest::USAGE_COLUMN.merge('usd' => usd)
    { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'Review the change.',
      'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'intent' => INTENT, 'verification' => VERIFICATION,
      'deployment' => 'none', 'steps_besides_merging' => 'none', 'provenance' => PUBLIC_PROVENANCE,
      'usage' => { 'note' => 'Native usage is PARTIAL.', 'records' => [USAGE_RECORD.merge('columns' => [column])] },
      'details' => [] }
  end

  def check_run(name, conclusion) = { 'name' => name, 'status' => 'COMPLETED', 'conclusion' => conclusion }
  def check(name, completed_at, bucket = 'pass') = { 'name' => name, 'bucket' => bucket, 'completedAt' => completed_at }

  def gql(oid, started, runs)
    suite = { 'createdAt' => started, 'checkRuns' => { 'nodes' => runs } }
    { 'oid' => oid, 'checkSuites' => { 'nodes' => [suite] } }
  end
end

# Serves one description and check history, and records each body write.
class ThroughputFakeGitHub
  attr_reader :patches
  attr_accessor :moved_pull

  def initialize(body, pull, checks)
    @body = body
    @pull = pull
    @checks = checks
    @patches = []
  end

  def repository = 'owner/repo'
  def number = 7
  def check_times = @checks

  def graphql(*)
    @graphql_calls = (@graphql_calls || 0) + 1
    { 'repository' => { 'pullRequest' => @graphql_calls > 1 && @moved_pull ? @moved_pull : @pull } }
  end

  def api(_path, method: 'GET', fields: {}, expected: Hash, headers: []) # rubocop:disable Lint/UnusedMethodArgument
    return { 'body' => @body } unless method == 'PATCH'

    @patches << (@body = fields.fetch(:body))
    { 'body' => @body }
  end
end
