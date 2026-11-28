# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_ownership_fixture'

# Releasing an unfinished PR, picking it up, and what the previous owner's checkout does afterward.
class BranchHeadHandoverTest < Minitest::Test
  include BranchHeadOwnershipFixture

  def test_pickup_needs_a_release
    push_task('first')
    error = assert_raises(Shaka::Error) { pickup(teammate_clone, 'newtag') }

    assert_includes error.message, 'not released'
    assert_empty @github.comments
  end

  def test_override_counts_only_from_a_maintainer
    push_task('first')

    assert_equal 'lost', pickup(teammate_clone, 'newtag', override: true)['state']
    assert_equal 'newtag', pickup(@teammate, 'newtag', as: 'maint', override: true)['owner']
    assert_includes last_comment, 'maintainer override'
  end

  def test_release_reports_head_checks_remaining_and_unpushed_work
    sha = push_task('first')
    commit(@task, 'unpushed')
    File.write(File.join(@task, 'draft.txt'), 'draft')
    checks = [{ 'conclusion' => 'SUCCESS' }, { 'conclusion' => '', 'state' => 'PENDING' }]
    handover(@task, 'origtag').release(pull_for(sha).merge('checks' => checks), maintainer: false)

    [sha, '1 passed, 1 pending', 'Write the docs', 'unpushed commits: 1', 'changed files: 1',
     'owner `origtag`'].each { |text| assert_includes last_comment, text }
  end

  def test_release_pauses_the_owner_until_a_pickup
    released_task

    assert_paused 'released', @task
    result = pickup(teammate_clone, 'newtag')

    assert_equal %w[picked_up unrecorded], [result['state'], result.dig('branch', 'state')]
    assert_paused 'taken_over', @task
    assert_paused nil, @teammate
  end

  def test_pickup_from_a_checkout_on_another_branch_posts_nothing
    released_task
    git(teammate_clone, 'switch', '--quiet', 'main')
    posted = @github.comments.size

    assert_raises(Shaka::Error) { pickup(@teammate, 'newtag') }
    assert_equal posted, @github.comments.size
    assert_true ownership.state['released']
  end

  def test_a_release_without_write_access_does_not_count
    error = assert_raises(Shaka::Error) { release(@task, 'origtag', push_task('first'), as: 'visitor') }

    assert_includes error.message, 'did not take effect'
    assert_false ownership.state['released']
  end

  # A PR taken over before release and pickup existed has an owner other than its author.
  def test_any_writer_may_release_before_the_first_pickup
    assert_equal 'released', release(@task, 'origtag', push_task('first'), as: 'teammate')['state']
  end

  def test_only_the_owner_or_a_maintainer_releases
    sha = released_task
    pickup(teammate_clone, 'newtag')
    error = assert_raises(Shaka::Error) { release(@task, 'origtag', sha) }

    assert_includes error.message, 'newtag owns this PR'
    release(@task, 'maint', sha, as: 'maint', maintainer: true)

    assert_includes last_comment, 'UNKNOWN: a maintainer released the PR without inspecting'
  end

  # A checkout that copies the winner's public tag still has to pass the pickup gate.

  def test_a_copied_owner_tag_does_not_bypass_pickup
    released_task
    pickup(teammate_clone, 'newtag')
    third = File.join(@dir, 'third')
    git(@dir, 'clone', '--quiet', '--branch', BRANCH, @origin, third)

    assert_raises(Shaka::Error) { pickup(third, 'newtag', as: 'other') }
    assert_paused 'taken_over', third
  end

  def test_pickup_needs_the_local_branch_at_the_pr_head
    released_task
    teammate_clone
    commit(@task, 'newer')
    git(@task, 'push', '--quiet', 'origin', BRANCH)
    posted = @github.comments.size

    assert_raises(Shaka::Error) { pickup(@teammate, 'newtag') }
    assert_equal posted, @github.comments.size
  end

  def test_pickup_needs_the_pr_branch_on_origin
    released_task
    teammate_clone
    git(@task, 'push', '--quiet', 'origin', '--delete', BRANCH)
    posted = @github.comments.size
    error = assert_raises(Shaka::Error) { pickup(@teammate, 'newtag') }

    assert_includes error.message, 'Cannot pick up from this checkout'
    assert_equal posted, @github.comments.size
  end
end
