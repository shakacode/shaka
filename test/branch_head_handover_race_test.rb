# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_ownership_fixture'

# Release and pickup writes that interleave, and a late wake in the old owner's chat after a hand-over.
class BranchHeadHandoverRaceTest < Minitest::Test
  include BranchHeadOwnershipFixture

  # Both checkouts read the PR as released before either posts; the comment GitHub stores first wins.
  def test_simultaneous_pickups_yield_one_owner
    released_task
    third = File.join(@dir, 'third')
    git(@dir, 'clone', '--quiet', '--branch', BRANCH, @origin, third)
    @github.before_post = -> { pickup(third, 'rival', as: 'other') }
    result = pickup(teammate_clone, 'newtag')

    assert_equal %w[lost rival], result.values_at('state', 'owner')
    assert_includes last_comment, 'did not take effect'
    assert_paused 'taken_over', @teammate
    assert_paused nil, third
    assert_nil Shaka::BranchHead::OwnerTag.recorded(@teammate)
  end

  # A second release made against the original owner lands after the PR changed hands, and changes nothing.
  def test_a_stale_release_does_not_revoke_a_pickup
    sha = push_task('first')
    teammate_clone
    @github.before_post = -> { stale_release_race(sha) }
    error = assert_raises(Shaka::Error) { release(@task, 'origtag', sha) }

    assert_includes error.message, 'did not take effect'
    assert_equal 'newtag', ownership.state['owner']
    assert_includes last_comment, 'This release did not take effect'
  end

  # A monitor wakes the old chat after the hand-over: its ownership status and its push both pause, and the new
  # owner's push stays.
  def test_late_wake_after_release_leaves_the_new_owners_work_alone
    theirs = handed_over
    assert_equal 'taken_over', command(Shaka::BranchHead::HandoverCommand, 'status', '--pr', 'base/repo#7')
    assert_equal 'moved', command(Shaka::BranchHead::Command, 'push')
    assert_equal theirs, git(@dir, '--git-dir', @origin, 'rev-parse', BRANCH).strip
  end

  # The teammate picks up between the release and the releaser's confirming read; the release still counted.
  def test_a_release_picked_up_before_its_confirmation_reports_success
    sha = push_task('first')
    teammate_clone
    @github.after_post = -> { pickup(@teammate, 'newtag').then { @github.login = 'owner' } }

    assert_equal 'released', release(@task, 'origtag', sha)['state']
    refute_includes @github.comments.first['body'], 'did not take effect'
  end

  # The pickup comment is stored and then the command dies; a retry with the same tag finishes without posting again.
  def test_a_pickup_interrupted_after_posting_can_be_finished
    released_task
    teammate_clone
    @github.after_post = -> { raise Shaka::Error, 'interrupted' }
    assert_raises(Shaka::Error) { pickup(@teammate, 'newtag') }
    posted = @github.comments.size

    assert_equal 'picked_up', pickup(@teammate, 'newtag')['state']
    assert_equal posted, @github.comments.size
    assert_paused nil, @teammate
  end

  private

  def stale_release_race(sha)
    release(@task, 'origtag', sha)
    pickup(@teammate, 'newtag')
    @github.login = 'owner'
  end

  # The task released, the teammate picked up and pushed, and the old checkout made a late commit.
  def handed_over
    accept(push_task('first'))
    release(@task, 'origtag', check['live'])
    pickup(teammate_clone, 'newtag')
    theirs = teammate_push('new owner')
    commit(@task, 'late')
    @github.pull_head = theirs
  end

  def command(program, operation, *flags)
    output, = capture_io do
      assert_equal 2, program.run([operation, '--root', @task, *flags])
    end
    JSON.parse(output)['state']
  end
end
