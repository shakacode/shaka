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
    %w[true 2].each do |value|
      git(@task, 'config', 'remote.origin.mirror', value)

      assert_includes check['error'], 'mirror', "remote.origin.mirror=#{value}"
    end
  end

  # ls-remote and push can read a URL with edge whitespace or a newline differently, so such URLs pause.
  def test_push_url_with_edge_whitespace_or_newline_pauses
    [' ', "\r", "\n"].each do |suffix|
      git(@task, 'remote', 'set-url', '--push', 'origin', "#{@origin}#{suffix}")

      assert_equal 'unreadable', check['state'], suffix.inspect
    end
  end
end
