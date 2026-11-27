# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# How `--pr OWNER/REPO#NUMBER` is looked up, and push settings whose effective value is not origin.
class BranchHeadPrTest < Minitest::Test
  include BranchHeadFixture

  # Recorded gh call, answered with a fixed PR so no network is used.
  FakeCommand = Struct.new(:calls, :answer) do
    def call(argv, _chdir = nil)
      calls << argv
      [answer, '', true]
    end
  end

  def test_pr_lookup_names_the_origin_push_host_and_repository
    git(@task, 'remote', 'set-url', 'origin', 'https://fetch.example.com/base/repo.git')
    git(@task, 'remote', 'set-url', '--push', 'origin', 'https://push.example.com/base/repo.git')
    argv = lookup(state: 'MERGED')

    assert_equal(%w[--repo push.example.com/base/repo], argv.each_cons(2).find { |flag, _| flag == '--repo' })
  end

  def test_empty_last_push_default_still_overrides_origin
    git(@task, 'config', '--add', 'remote.pushDefault', 'origin')
    git(@task, 'config', '--add', 'remote.pushDefault', '')
    result = check

    assert_equal 'unreadable', result['state']
    assert_includes result['error'], 'origin only'
  end

  private

  def lookup(state:)
    fake = FakeCommand.new([], JSON.generate('url' => 'https://push.example.com/base/repo/pull/7', 'state' => state))
    with_bounded_command(fake) do
      capture_io { Shaka::BranchHead::Command.run(['check', '--root', @task, '--pr', 'base/repo#7']) }
    end
    fake.calls.first
  end

  def with_bounded_command(fake)
    original = Shaka::Doctor::BoundedCommand.method(:new)
    Shaka::Doctor::BoundedCommand.define_singleton_method(:new) { |**| fake }
    yield
  ensure
    Shaka::Doctor::BoundedCommand.define_singleton_method(:new, original)
  end
end
