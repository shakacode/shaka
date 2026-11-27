# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# Which state `shaka branch check` reports for each remote branch history.
class BranchHeadTest < Minitest::Test
  include BranchHeadFixture

  def test_new_branch_is_not_pushed
    assert_equal 'not_pushed', check['state']
  end

  def test_own_push_then_accept_keeps_the_head_unchanged
    pushed = push_task('first')
    accept(pushed)
    result = check

    assert_equal 'unchanged', result['state']
    assert_equal pushed, result['accepted']
  end

  def test_teammate_push_between_turns_reads_as_moved
    accept(push_task('first'))
    theirs = teammate_push('theirs')
    result = check

    assert_equal 'moved', result['state']
    assert_equal theirs, result['live']
  end

  # A fetch or pull moves the remote-tracking ref, so the accepted head must come from elsewhere.
  def test_fetching_the_teammate_push_does_not_hide_it
    accept(push_task('first'))
    teammate_push('theirs')
    git(@task, 'pull', '--quiet', '--ff-only', 'origin', BRANCH)

    assert_equal 'moved', check['state']
  end

  def test_branch_on_remote_without_a_record_is_unrecorded
    push_task('first')

    assert_equal 'unrecorded', check['state']
  end

  def test_deleted_branch_reads_as_disappeared_until_accepted_absent
    accept(push_task('first'))
    git(@task, 'push', '--quiet', 'origin', '--delete', BRANCH)

    assert_equal 'disappeared', check['state']
    assert_equal 'not_pushed', branch_head.accept(nil, absent: true)['state']
  end

  def test_unreadable_remote_is_never_treated_as_absent
    accept(push_task('first'))
    git(@task, 'remote', 'set-url', 'origin', File.join(@dir, 'missing.git'))
    result = check

    assert_equal 'unreadable', result['state']
    assert_kind_of String, result['error']
    refute_empty result['error']
  end

  # ls-remote matches patterns by suffix, so a ref ending in the branch path must not stand in for it.
  def test_ref_that_only_ends_in_the_branch_name_is_ignored
    push_task('first')
    git(@task, 'push', '--quiet', 'origin', "HEAD:refs/heads/other/refs/heads/#{BRANCH}")
    git(@task, 'push', '--quiet', 'origin', '--delete', BRANCH)

    assert_equal 'not_pushed', check['state']
  end

  def test_accept_refuses_a_head_the_remote_does_not_hold
    push_task('first')
    stale = git(@task, 'rev-parse', 'HEAD~1').strip

    error = assert_raises(Shaka::Error) { accept(stale) }
    assert_includes error.message, 'check it again'
    assert_raises(Shaka::Error) { accept('abc123') }
  end

  # The branch is captured once, so a checkout switch mid-command cannot make another branch's tip the local head.
  def test_local_head_is_the_task_branch_after_a_checkout_switch
    commit(@task, 'first')
    task_tip = git(@task, 'rev-parse', 'HEAD').strip
    head = branch_head
    git(@task, 'switch', '--quiet', '-c', 'other')
    commit(@task, 'elsewhere')

    assert_equal task_tip, head.check['local']
  end
end
