# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/local_review/windows_tree'

# The Windows stop shared by local review and evidence run, with the job and taskkill missing or
# stalled as they can be on Windows. The hosted windows job runs it with both present.
class WindowsReviewStopTest < Minitest::Test
  # Off Windows kernel32 cannot load, as when job support fails there, so the stop falls back.
  def test_failed_job_support_leaves_the_stop_to_taskkill
    original = Shaka::ExecutableFile.method(:windows?)
    Shaka::ExecutableFile.define_singleton_method(:windows?) { true }

    assert_nil Shaka::LocalReviewWindowsTree.adopt(Process.pid)
  ensure
    Shaka::ExecutableFile.define_singleton_method(:windows?, original)
  end

  def test_a_stalled_taskkill_does_not_hold_the_bounded_wait
    with_stalled_taskkill do
      Open3.popen3(RbConfig.ruby, '-e', 'sleep 120') do |input, _output, _error, waiter|
        input.close
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Shaka::LocalReviewWindowsTree.end_tree(waiter, nil, seconds: 0.5)

        refute_predicate waiter, :alive?
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 10
      end
    end
  end

  private

  def with_stalled_taskkill
    Dir.mktmpdir('shaka-windows-taskkill') do |directory|
      stalled = File.join(directory, 'taskkill')
      File.write(stalled, "#!/bin/sh\nsleep 30\n", perm: 0o755)
      tree = Shaka::LocalReviewWindowsTree.singleton_class
      tree.alias_method(:system_taskkill, :taskkill)
      tree.define_method(:taskkill) { stalled }
      yield
    ensure
      tree&.alias_method(:taskkill, :system_taskkill)
    end
  end
end
