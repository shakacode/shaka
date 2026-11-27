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
    result = Shaka::BranchHead.new(root: @task,
                                   pr_head: {
                                     'url' => 'https://github.com/someone/fork', 'branch' => BRANCH
                                   }).check

    assert_equal 'unreadable', result['state']
    assert_includes result['error'], 'someone/fork'
  end

  def test_pr_head_matching_the_destination_is_checked_normally
    pr_head = { 'url' => @origin, 'branch' => BRANCH }

    assert_equal 'not_pushed', Shaka::BranchHead.new(root: @task, pr_head:).check['state']
  end

  def test_pr_head_on_another_host_is_unreadable
    git(@task, 'remote', 'set-url', '--push', 'origin', 'https://git.example.com/someone/fork.git')
    pr_head = { 'url' => 'https://github.com/someone/fork', 'branch' => BRANCH }

    assert_includes Shaka::BranchHead.new(root: @task, pr_head:).check['error'], 'git.example.com'
  end

  def test_sole_remote_not_named_origin_is_the_destination
    git(@task, 'remote', 'rename', 'origin', 'upstream')
    result = check

    assert_equal %w[upstream not_pushed], result.values_at('remote', 'state')
  end

  # gh pr checkout records a fork PR's remote as a URL.
  def test_remote_given_as_a_url_is_its_own_push_url
    git(@task, 'config', "branch.#{BRANCH}.remote", @origin)
    git(@task, 'config', "branch.#{BRANCH}.merge", "refs/heads/#{BRANCH}")
    commit(@task, 'first')

    assert_equal 'unchanged', branch_head.push['state']
  end

  def test_tracking_the_base_branch_while_pushing_to_a_fork_is_allowed
    fork = bare_copy('fork.git')
    git(@task, 'remote', 'add', 'fork', fork)
    git(@task, 'config', "branch.#{BRANCH}.remote", 'origin')
    git(@task, 'config', "branch.#{BRANCH}.merge", 'refs/heads/main')
    git(@task, 'config', "branch.#{BRANCH}.pushRemote", 'fork')

    assert_equal %w[fork not_pushed], check.values_at('remote', 'state')
  end

  # Git skips pushInsteadOf for an explicit push URL, so the push lands where the check read.
  def test_push_lands_at_the_explicit_push_url_despite_push_insteadof
    fork = bare_copy('fork.git')
    git(@task, 'config', 'remote.origin.pushurl', @origin)
    git(@task, 'config', "url.#{fork}.pushInsteadOf", @origin)
    commit(@task, 'first')

    assert_equal 'unchanged', branch_head.push['state']
    assert_empty git(@task, 'ls-remote', fork, "refs/heads/#{BRANCH}")
  end

  def test_pr_view_json_maps_to_the_head_url_and_refuses_a_deleted_fork
    pull = { 'url' => 'https://github.com/base/repo/pull/7', 'headRefName' => 'topic',
             'headRepository' => { 'name' => 'repo' }, 'headRepositoryOwner' => { 'login' => 'someone' } }

    assert_equal({ 'url' => 'https://github.com/someone/repo', 'branch' => 'topic' },
                 Shaka::BranchHead::Command.send(:head_of, pull, 7))
    assert_raises(Shaka::Error) { Shaka::BranchHead::Command.send(:head_of, pull.merge('headRepository' => nil), 7) }
  end

  private

  def bare_copy(name)
    path = File.join(@dir, name)
    git(@dir, 'clone', '--quiet', '--bare', @origin, path)
    path
  end

  def unreadable_error
    result = check

    assert_equal 'unreadable', result['state']
    result['error']
  end
end
