# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# Destinations where the branch read could differ from the branch a push writes are refused, not guessed.
class BranchHeadDestinationTest < Minitest::Test
  include BranchHeadFixture

  def test_custom_push_refspec_is_unreadable
    git(@task, 'config', 'remote.origin.push', "refs/heads/#{BRANCH}:refs/heads/elsewhere")

    assert_includes unreadable_error, 'custom push refspec'
  end

  def test_push_remote_other_than_the_same_named_upstream_is_unreadable
    fork = File.join(@dir, 'fork.git')
    git(@dir, 'clone', '--quiet', '--bare', @origin, fork)
    git(@task, 'remote', 'add', 'fork', fork)
    git(@task, 'config', "branch.#{BRANCH}.remote", 'fork')
    git(@task, 'config', "branch.#{BRANCH}.merge", "refs/heads/#{BRANCH}")
    git(@task, 'config', 'remote.pushDefault', 'origin')

    assert_includes unreadable_error, 'pushes to origin'
  end

  def test_push_url_that_insteadof_rewrites_again_is_unreadable
    git(@task, 'remote', 'set-url', '--push', 'origin', 'alias:repo')
    git(@task, 'config', 'url.mirror:.insteadOf', 'alias:')
    git(@task, 'config', "url.#{@origin}.insteadOf", 'mirror:')

    assert_includes unreadable_error, 'insteadOf'
  end

  def test_upstream_on_the_base_branch_does_not_block_the_task_branch
    git(@task, 'config', "branch.#{BRANCH}.remote", 'origin')
    git(@task, 'config', "branch.#{BRANCH}.merge", 'refs/heads/main')

    assert_equal 'not_pushed', check['state']
  end

  # symbolic-ref --short spells a branch shadowed by a same-named tag as heads/NAME.
  def test_tag_with_the_branch_name_does_not_change_the_branch_read
    commit(@task, 'first')
    git(@task, 'tag', BRANCH)

    assert_equal BRANCH, check['branch']
  end

  def test_pr_head_in_another_repository_is_unreadable
    result = Shaka::BranchHead.new(root: @task, pr_head: { 'repository' => 'someone/fork', 'branch' => BRANCH }).check

    assert_equal 'unreadable', result['state']
    assert_includes result['error'], 'someone/fork'
  end

  def test_pr_head_matching_the_destination_is_checked_normally
    pr_head = { 'repository' => @origin, 'branch' => BRANCH }

    assert_equal 'not_pushed', Shaka::BranchHead.new(root: @task, pr_head:).check['state']
  end

  private

  def unreadable_error
    result = check

    assert_equal 'unreadable', result['state']
    result['error']
  end
end
