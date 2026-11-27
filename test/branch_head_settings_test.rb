# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# Push settings whose effective destination is not origin's same-named branch pause the check.
class BranchHeadSettingsTest < Minitest::Test
  include BranchHeadFixture

  def test_empty_last_push_default_still_overrides_origin
    git(@task, 'config', '--add', 'remote.pushDefault', 'origin')
    git(@task, 'config', '--add', 'remote.pushDefault', '')

    assert_includes check['error'], 'origin only'
  end

  # A plain push follows a named upstream remote, so tracking a fork's branch would send the push there.
  def test_upstream_on_another_remote_pauses_the_check
    git(@task, 'remote', 'add', 'fork', bare_copy('fork.git'))
    git(@task, 'config', "branch.#{BRANCH}.remote", 'fork')

    assert_includes check['error'], 'tracks fork'
  end

  # A mirror remote refuses a single-branch push, so the check pauses before any edit.
  def test_mirror_remote_pauses_the_check
    git(@task, 'config', 'remote.origin.mirror', 'true')

    assert_includes check['error'], 'mirror'
  end
end
