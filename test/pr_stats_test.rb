# frozen_string_literal: true

require_relative 'throughput_helper'
require 'open3'
require 'shaka/pr_watch/stats_command'

# After a GitHub merge click, pr stats fills the times no watcher recorded.
class PrStatsTest < Minitest::Test
  include ThroughputHelper

  Seam = Struct.new(:merge, :review)
  SEAM = Seam.new({}, { 'ci_review_jobs' => [], 'ci_review_wait' => 'none' })

  def test_a_merged_pull_request_gets_its_ready_and_merge_times
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    result = Shaka::PrWatch::StatsCommand.record(github, SEAM)

    assert_equal 2, github.patches.size
    assert_includes github.patches.last, 'CI to ready 41m · Ready to merged 2h 5m'
    assert_equal({ 't2' => READY.iso8601, 't3' => MERGED.iso8601 }, result['stats'].slice('t2', 't3'))
  end

  def test_a_second_run_writes_nothing
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    2.times { Shaka::PrWatch::StatsCommand.record(github, SEAM) }
    assert_equal 2, github.patches.size
  end

  def test_a_check_rerun_after_the_merge_does_not_become_the_ready_time
    rerun = [check('validate', (MERGED + 600).iso8601)]
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page, rerun)
    stats = Shaka::PrWatch::StatsCommand.record(github, SEAM)['stats']

    assert_nil stats['t2']
    assert_equal MERGED.iso8601, stats['t3']
    assert_includes github.patches.last, 'CI to ready UNKNOWN · Ready to merged UNKNOWN'
  end

  def test_unreadable_required_checks_still_record_the_merge_and_say_why
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    def github.required_checks = raise(Shaka::Error, 'rules unreadable')

    _, err = capture_io { assert_equal MERGED.iso8601, Shaka::PrWatch::StatsCommand.record(github, SEAM)['stats']['t3'] }
    assert_includes err, 'no ready time recorded: rules unreadable'
  end

  def test_an_unreadable_check_list_still_records_the_merge
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    def github.check_times = raise(Shaka::Error, 'checks unreadable')

    _, err = capture_io { assert_equal MERGED.iso8601, Shaka::PrWatch::StatsCommand.record(github, SEAM)['stats']['t3'] }
    assert_includes err, 'no ready time recorded: checks unreadable'
  end

  def test_unreadable_checks_still_move_an_earlier_heads_block_to_the_merge
    earlier = Shaka::ThroughputStats.update(filled_block, 'head' => NEXT)
    github = MergedFakeGitHub.new("Intro.\n\n#{earlier}\n", merged_page)
    def github.check_times = raise(Shaka::Error, 'checks unreadable')

    stats = nil
    capture_io { stats = Shaka::PrWatch::StatsCommand.record(github, SEAM)['stats'] }
    assert_equal [HEAD, nil, MERGED.iso8601], stats.values_at('head', 't2', 't3')
  end

  def test_unreadable_checks_mark_a_forks_carried_ready_time_unverified
    github = MergedFakeGitHub.new("Intro.\n\n#{filled_block}\n", merged_page.merge('isCrossRepository' => true))
    def github.check_times = raise(Shaka::Error, 'checks unreadable')

    capture_io { Shaka::PrWatch::StatsCommand.record(github, SEAM) }
    assert_includes github.patches.last, 'Ready time unverified'
  end

  def test_a_pull_request_without_a_stats_block_is_not_written
    github = MergedFakeGitHub.new("Written by hand.\n", merged_page)
    assert_nil Shaka::PrWatch::StatsCommand.record(github, SEAM)['stats']
    assert_empty github.patches
  end

  def test_the_command_reads_its_arguments_and_prints_the_recorded_stats
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    out, = capture_io do
      with_stubs(github) { assert_equal 0, Shaka::PrWatch::StatsCommand.run(%w[owner/repo 7 --ref main]) }
    end
    assert_equal MERGED.iso8601, JSON.parse(out).dig('stats', 't3')
  end

  def test_the_command_fails_when_the_merge_time_was_not_recorded
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page.except('mergedAt'))
    _, err = capture_io do
      with_stubs(github) { assert_equal 1, Shaka::PrWatch::StatsCommand.run(%w[owner/repo 7 --ref main]) }
    end
    assert_includes err, 'the merge time was not recorded'
  end

  def test_an_unknown_merge_time_also_fails_the_command
    block = Shaka::ThroughputStats.update(unready_block, 't3' => 'UNKNOWN')
    github = MergedFakeGitHub.new("Intro.\n\n#{block}\n", merged_page.except('mergedAt'))
    capture_io do
      with_stubs(github) { assert_equal 1, Shaka::PrWatch::StatsCommand.run(%w[owner/repo 7 --ref main]) }
    end
  end

  def test_the_command_refuses_to_run_without_a_trusted_ref
    _, err = capture_io { assert_equal 1, Shaka::PrWatch::StatsCommand.run(%w[owner/repo 7]) }
    assert_includes err, '--ref SHA'
  end

  def test_the_helper_dispatches_pr_stats
    output, status = Open3.capture2e('skills/shaka/scripts/shaka', 'pr', 'stats', '--help',
                                     chdir: File.expand_path('..', __dir__))
    assert_predicate status, :success?, output
    assert_includes output, 'Usage: shaka pr stats OWNER/REPO NUMBER --ref SHA'
  end

  private

  def unready_block = describe('$4.12', timeline: push_times, pull: head_pull)

  def merged_page
    { 'headRefOid' => HEAD, 'mergedAt' => MERGED.iso8601,
      'commits' => { 'nodes' => [{ 'commit' => gql(HEAD, PUSH.iso8601, []) }] } }
  end

  # Replaces GitHub and the trusted settings for one block, so run exercises its real argument handling.
  def with_stubs(github)
    swaps = { Shaka::GitHub => [:new, github], Shaka::PrWatch::StatsCommand => [:trusted_seam, SEAM] }
    originals = swaps.to_h { |owner, (name, _)| [owner, owner.method(name)] }
    swaps.each { |owner, (name, value)| owner.define_singleton_method(name) { |*| value } }
    yield
  ensure
    originals.each { |owner, original| owner.define_singleton_method(original.name, original) }
  end
end

# A pull request GitHub merged after its required check passed, with nothing recorded since publication.
class MergedFakeGitHub < ThroughputFakeGitHub
  def initialize(body, pull, times = [{ 'name' => 'validate', 'bucket' => 'pass',
                                        'completedAt' => ThroughputHelper::READY.iso8601 }])
    super
  end

  def snapshot = { 'headRefOid' => ThroughputHelper::HEAD, 'state' => 'MERGED', 'baseRefName' => 'main' }
  def required_checks = [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
  def configured_required_checks = []
  def checks = required_checks
end
