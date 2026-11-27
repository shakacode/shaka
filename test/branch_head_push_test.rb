# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# How the printed lease and exit status guard pushes made during a turn.
class BranchHeadPushTest < Minitest::Test
  include BranchHeadFixture

  def test_teammate_push_during_the_turn_is_refused_by_the_lease
    accept(push_task('first'))
    lease = check['lease']
    teammate_push('theirs')
    commit(@task, 'mine')
    _output, status = Open3.capture2e('git', '-C', @task, 'push', lease, 'origin', "HEAD:refs/heads/#{BRANCH}")

    refute_predicate status, :success?
    assert_equal 'moved', check['state']
  end

  def test_own_rebase_force_push_is_allowed_by_the_lease
    accept(push_task('first'))
    git(@task, 'commit', '--quiet', '--amend', '--allow-empty', '-m', 'first, reworded')
    git(@task, 'push', '--quiet', check['lease'], 'origin', "HEAD:refs/heads/#{BRANCH}")
    rewritten = git(@task, 'rev-parse', 'HEAD').strip

    assert_equal 'moved', check['state'], 'Until accepted, the new head is not this task’s record.'
    accept(rewritten)

    assert_equal 'unchanged', check['state']
  end

  def test_command_exits_two_for_states_that_pause_work
    push_task('first')
    out, = capture_io { assert_equal Shaka::BranchHead::Command::PAUSE_EXIT, Shaka::BranchHead::Command.run(['check', '--root', @task]) }

    assert_equal 'unrecorded', JSON.parse(out)['state']
  end
end
