# frozen_string_literal: true

require_relative 'pr_stats_helper'

# After a GitHub merge click, pr stats fills the times no watcher recorded.
class PrStatsTest < Minitest::Test
  include PrStatsHelper

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
end
