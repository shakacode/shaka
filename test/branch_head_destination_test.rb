# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# Destinations where the branch read could differ from the branch a push writes are refused, not guessed.
class BranchHeadDestinationTest < Minitest::Test
  include BranchHeadFixture

  def test_custom_push_refspec_is_unreadable
    git(@task, 'config', 'remote.origin.push', "refs/heads/#{BRANCH}:refs/heads/elsewhere")

    assert_includes unreadable_error, 'push refspec'
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

  def test_push_default_other_than_origin_is_unreadable
    git(@task, 'config', 'remote.pushDefault', '.')

    assert_includes unreadable_error, 'origin only'
  end

  # Git uses the last value of a repeated key, so a later override wins over an earlier origin.
  def test_later_push_default_overrides_an_earlier_origin
    git(@task, 'config', '--add', 'remote.pushDefault', 'origin')
    git(@task, 'config', '--add', 'remote.pushDefault', '.')

    assert_includes unreadable_error, 'origin only'
  end

  def test_checkout_without_origin_is_unreadable
    git(@task, 'remote', 'rename', 'origin', 'upstream')

    assert_equal 'unreadable', check['state']
  end

  # gh pr checkout can record a fork's URL, with credentials, as the branch upstream; it pauses without printing them.
  def test_upstream_url_pauses_and_is_never_printed
    git(@task, 'config', "branch.#{BRANCH}.remote", 'https://user:secret@git.example.com/someone/fork.git')
    git(@task, 'config', "branch.#{BRANCH}.merge", "refs/heads/#{BRANCH}")
    result = check

    assert_equal %w[origin unreadable], result.values_at('remote', 'state')
    refute_includes JSON.generate(result), 'secret'
  end

  # symbolic-ref --short spells a branch shadowed by a same-named tag as heads/NAME.
  def test_tag_with_the_branch_name_does_not_change_the_branch_read
    commit(@task, 'first')
    git(@task, 'tag', BRANCH)

    assert_equal BRANCH, check['branch']
  end

  def test_printed_errors_drop_url_credentials
    ['user:secret', 'user:two words', 'user:pa/ss', 'user:p@ss'].each do |userinfo|
      assert_equal 'see https://git.example.com/o/r', Shaka::BranchHead.redact("see https://#{userinfo}@git.example.com/o/r")
    end
    diagnostic = "fatal: unable to access 'https://git.example.com'\nhint: contact ops@example.com"

    assert_equal diagnostic, Shaka::BranchHead.redact(diagnostic), 'redaction stays on one line'
  end

  # A rejected upstream is never echoed, so a password the redaction cannot parse still stays out of the output.
  def test_rejected_upstream_value_is_never_printed
    git(@task, 'config', "branch.#{BRANCH}.remote", 'https://user:two words@git.example.com/o/r')

    refute_includes JSON.generate(check), 'words'
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

  private

  def unreadable_error
    result = check

    assert_equal 'unreadable', result['state']
    result['error']
  end
end
