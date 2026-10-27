# frozen_string_literal: true

require_relative 'throughput_helper'

# pr watch fills the stats block once per head and never moves a known time later.
class ThroughputWatchTest < Minitest::Test
  include ThroughputHelper

  def test_pr_watch_patches_the_block_once_and_keeps_the_surrounding_text
    github = watch_github
    2.times { publish(github, ['claude-review'], 'one') }
    assert_equal 1, github.patches.size
    patched = github.patches.first
    assert patched.start_with?("Intro.\n\n") && patched.end_with?("\n\nOutro.\n")
    assert_includes patched, 'CI to ready 1h 19m (2 rounds)'
    assert_includes patched, 'Prompt to CI 38m'
  end

  def test_a_cut_off_history_keeps_the_earlier_first_push
    kept = watch_cut_off(filled_block)
    assert_includes kept, "\"first_push\":\"#{PUSH.iso8601}\""
    refute_includes kept, LATER.iso8601
    assert_includes kept, 'UNKNOWN rounds'
    invented = watch_cut_off(Shaka::ThroughputStats.update(filled_block, 'first_push' => nil))
    assert_includes invented, '"first_push":"UNKNOWN"'
  end

  def test_a_cut_off_history_on_first_publication_leaves_the_first_push_unknown
    first = watch_cut_off(describe('$4.12', timeline: push_times, pull: head_pull))
    assert_includes first, '"first_push":"UNKNOWN"'
  end

  def test_pr_watch_fills_prompt_to_ci_from_the_check_suite_without_a_push_time
    body = "Intro.\n\n#{describe('$4.12', timeline: { 'task_started_at' => START }, pull: head_pull)}\n"
    prompted = ThroughputFakeGitHub.new(body, one_commit(nil, PUSH.iso8601), [check('validate', READY.iso8601)])
    publish(prompted, [], 'none')
    assert_includes prompted.patches.fetch(0), 'Prompt to CI 38m'
  end

  def test_a_rerun_check_does_not_move_the_ready_time_later
    rerun = ThroughputFakeGitHub.new("Intro.\n\n#{filled_block}\n", history,
                                     [check('validate', (READY + 3600).iso8601)])
    publish(rerun, [], 'none')
    text = rerun.patches.last || "Intro.\n\n#{filled_block}\n"
    assert_includes text, READY.iso8601
    refute_includes text, (READY + 3600).iso8601
  end

  def test_a_head_that_moves_before_the_write_is_not_patched
    moved = watch_github
    moved.moved_pull = history.merge('headRefOid' => NEXT)
    publish(moved, [], 'none')
    assert_empty moved.patches
  end

  def test_a_ready_time_from_an_earlier_head_is_dropped_for_the_new_head
    earlier = Shaka::ThroughputStats.update(filled_block, 'head' => NEXT)
    github = ThroughputFakeGitHub.new("Intro.\n\n#{earlier}\n", history, [])
    publish(github, [], 'none')
    assert_includes github.patches.fetch(0), 'CI to ready pending'
  end

  private

  def publish(github, jobs, wait)
    Shaka::PrWatch::ThroughputPublisher.new(github, head: HEAD, review_jobs: jobs, wait:).call(required: ['validate'])
  end

  def watch_cut_off(block)
    page = { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 60, 'nodes' => [
      { 'commit' => gql(HEAD, LATER.iso8601, [check_run('validate', 'SUCCESS')]) }
    ] } }
    github = ThroughputFakeGitHub.new("Intro.\n\n#{block}\n", page, [check('validate', READY.iso8601)])
    publish(github, [], 'none')
    github.patches.fetch(0)
  end

  def watch_github
    body = "Intro.\n\n#{describe('$4.12', timeline: push_times, pull: head_pull)}\n\nOutro.\n"
    ThroughputFakeGitHub.new(body, history, [check('validate', READY.iso8601), check('claude-review', READY.iso8601)])
  end

  def one_commit(pushed, created)
    commit = gql(HEAD, pushed, [check_run('validate', 'SUCCESS')])
    commit['checkSuites']['nodes'][0]['createdAt'] = created
    { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 1, 'nodes' => [{ 'commit' => commit }] } }
  end

  def nodes(commits) = commits.map { |commit| { 'commit' => commit } }
  def history = { 'headRefOid' => HEAD, 'commits' => { 'totalCount' => 2, 'nodes' => nodes(commit_runs) } }
end
