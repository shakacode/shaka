# frozen_string_literal: true

require_relative 'pr_stats_helper'
require 'open3'

# The pr stats command reads its arguments and fails visibly when the merge time is missing.
class PrStatsCommandTest < Minitest::Test
  include PrStatsHelper

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

  def test_a_failed_ready_write_fails_the_command_instead_of_dropping_the_ready_time
    github = MergedFakeGitHub.new("Intro.\n\n#{unready_block}\n", merged_page)
    def github.api(path, method: 'GET', **) = method == 'PATCH' && patches.empty? ? raise(Shaka::Error, 'busy') : super
    capture_io do
      with_stubs(github) { assert_equal 1, Shaka::PrWatch::StatsCommand.run(%w[owner/repo 7 --ref main]) }
    end
    assert_empty github.patches
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
end
