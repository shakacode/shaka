# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# How `shaka branch push` guards the push it makes, and where it reads the branch from.
class BranchHeadPushTest < Minitest::Test
  include BranchHeadFixture

  def test_first_push_creates_the_branch_and_accepts_it
    commit(@task, 'first')
    result = branch_head.push

    assert_true result['pushed']
    assert_equal 'unchanged', result['state']
    assert_equal git(@task, 'rev-parse', 'HEAD').strip, result['accepted']
  end

  def test_push_after_a_teammate_push_does_not_push
    accept(push_task('first'))
    theirs = teammate_push('theirs')
    commit(@task, 'mine')
    result = branch_head.push

    assert_false result['pushed']
    assert_equal 'moved', result['state']
    assert_equal theirs, check['live']
  end

  # The task builds on the teammate's commit, so a plain push would fast-forward; only the lease refuses it.
  def test_lease_refuses_a_teammate_push_that_lands_after_the_check
    accepted = push_task('first')
    accept(accepted)
    theirs = teammate_push('theirs')
    git(@task, 'pull', '--quiet', '--ff-only', 'origin', BRANCH)
    commit(@task, 'mine')

    assert_raises(Shaka::Error) { Shaka::BranchHead::Destination.new(root: @task, branch: BRANCH).push(accepted) }
    assert_equal theirs, check['live']
  end

  def test_rewrite_needs_explicit_permission
    accept(push_task('first'))
    git(@task, 'commit', '--quiet', '--amend', '--allow-empty', '-m', 'first, reworded')

    assert_true check['rewrites']
    error = assert_raises(Shaka::Error) { branch_head.push }
    assert_includes error.message, '--rewrite'
    assert_equal 'unchanged', branch_head.push(rewrite: true)['state']
  end

  def test_branch_push_remote_is_the_destination
    fork = bare_copy('fork.git')
    git(@task, 'remote', 'add', 'fork', fork)
    git(@task, 'config', "branch.#{BRANCH}.pushRemote", 'fork')
    commit(@task, 'first')

    assert_equal 'fork', branch_head.push['remote']
    refute_empty git(@task, 'ls-remote', fork, "refs/heads/#{BRANCH}")
    assert_empty git(@task, 'ls-remote', @origin, "refs/heads/#{BRANCH}")
  end

  # A remote may fetch from one repository and push to another; the push URL is the one that matters.
  def test_check_reads_the_push_url_not_the_fetch_url
    fork = bare_copy('fork.git')
    git(@task, 'remote', 'set-url', '--push', 'origin', fork)
    commit(@task, 'first')

    assert_equal 'unchanged', branch_head.push['state']
    assert_empty git(@task, 'ls-remote', @origin, "refs/heads/#{BRANCH}"), 'The fetch URL never got the branch.'
  end

  def test_command_exit_status_follows_the_returned_state
    pushed = push_task('first')
    out, = capture_io { assert_equal 2, Shaka::BranchHead::Command.run(['check', '--root', @task]) }

    assert_equal 'unrecorded', JSON.parse(out)['state']
    capture_io { assert_equal 0, Shaka::BranchHead::Command.run(['accept', '--root', @task, '--head', pushed]) }
  end

  private

  def bare_copy(name)
    path = File.join(@dir, name)
    git(@dir, 'clone', '--quiet', '--bare', @origin, path)
    path
  end
end
