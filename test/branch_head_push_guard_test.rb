# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# What `shaka branch push` refuses, and what it reports when a push lands but cannot be recorded.
class BranchHeadPushGuardTest < Minitest::Test
  include BranchHeadFixture

  def test_push_refuses_every_pausing_state
    pushed = push_task('first')

    assert_equal %w[unrecorded false], push_outcome
    accept(pushed)
    git(@task, 'push', '--quiet', 'origin', '--delete', BRANCH)

    assert_equal %w[disappeared false], push_outcome
    assert_empty git(@task, 'ls-remote', @origin, "refs/heads/#{BRANCH}")
  end

  # A teammate push landing between the check and the push reaches Git, whose lease refuses it.
  def test_teammate_push_after_the_check_is_refused_through_the_command
    accepted = push_task('first')
    accept(accepted)
    commit(@task, 'mine')
    head = branch_head
    theirs = nil
    before_push(head) { theirs = teammate_push('theirs') }

    assert_raises(Shaka::Error) { head.push }
    assert_equal theirs, check['live']
    assert_equal accepted, check['accepted']
  end

  # The task builds on the teammate's commit, so a plain push would fast-forward; only the lease refuses it.
  def test_lease_refuses_a_push_a_plain_push_would_fast_forward
    accepted = push_task('first')
    accept(accepted)
    theirs = teammate_push('theirs')
    git(@task, 'pull', '--quiet', '--ff-only', 'origin', BRANCH)
    commit(@task, 'mine')
    destination = Shaka::BranchHead::Destination.new(root: @task, branch: BRANCH)

    assert_raises(Shaka::Error) { destination.push(accepted, git(@task, 'rev-parse', 'HEAD').strip) }
    assert_equal theirs, check['live']
  end

  def test_push_that_lands_but_cannot_be_accepted_names_the_pushed_commit
    accept(push_task('first'))
    commit(@task, 'mine')
    head = branch_head
    head.singleton_class.prepend(Module.new { def accept(*) = raise(Shaka::Error, 'read failed') })
    result = head.push

    assert_true result['pushed']
    assert_equal result['local'], result['pushed_head']
    assert_equal 'moved', result['state']
  end

  def test_several_push_urls_are_unreadable
    git(@task, 'remote', 'set-url', '--add', '--push', 'origin', @origin)
    git(@task, 'remote', 'set-url', '--add', '--push', 'origin', File.join(@dir, 'other.git'))

    assert_equal 'unreadable', check['state']
    assert_includes check['error'], '2 push URLs'
  end

  def test_push_sends_no_tags
    git(@task, 'config', 'push.followTags', 'true')
    commit(@task, 'first')
    git(@task, 'tag', '-a', '-m', 'release', 'v1')
    branch_head.push

    assert_empty git(@task, 'ls-remote', '--tags', @origin)
  end

  private

  def push_outcome
    result = branch_head.push
    [result['state'], result['pushed'].to_s]
  end

  def before_push(head, &)
    destination = head.instance_variable_get(:@destination)
    destination.singleton_class.prepend(Module.new do
      define_method(:push) do |accepted, sha|
        yield
        super(accepted, sha)
      end
    end)
  end
end
