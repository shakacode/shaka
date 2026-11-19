# frozen_string_literal: true

require_relative 'test_helper'
require 'benchmark'
require 'shaka/local_review/windows_tree'

# The Windows stop shared by local review and evidence run, with the job and taskkill missing or
# stalled as they can be on Windows. The hosted windows job runs it with both present.
class WindowsReviewStopTest < Minitest::Test
  # Off Windows kernel32 cannot load, as when job support fails there, so the stop falls back.
  # On Windows the job would load and hold this test runner.
  def test_failed_job_support_leaves_the_stop_to_taskkill
    skip 'kernel32 loads on Windows' if Shaka::ExecutableFile.windows?

    assert_output(nil, /no Windows job holds the process/) do
      assert_nil(as_windows { Shaka::LocalReviewWindowsTree.adopt(Process.pid) })
    end
  end

  # taskkill steps in only when no job ended the tree.
  def test_taskkill_starts_only_when_the_job_did_not_end_the_tree
    assert_equal [[:taskkill]], stopped_with(Struct.new(:terminate).new(false))
    assert_empty stopped_with(Struct.new(:terminate).new(true))
    assert_equal [[:taskkill]], stopped_with(nil)
  end

  # The stalled stand-in is a shell script, which Windows cannot start directly.
  def test_a_stalled_taskkill_does_not_hold_the_bounded_wait
    skip 'the stalled stand-in needs a shell' if Shaka::ExecutableFile.windows?

    with_stalled_taskkill do |marker|
      Open3.popen3(RbConfig.ruby, '-e', 'sleep 120') do |input, _output, _error, waiter|
        input.close
        seconds = Benchmark.realtime { Shaka::LocalReviewWindowsTree.end_tree(waiter, nil, seconds: 2) }

        assert_path_exists marker, 'the stalled taskkill never started'
        refute_predicate waiter, :alive?
        assert_operator seconds, :<, 10
      end
    end
  end

  private

  def as_windows
    original = Shaka::ExecutableFile.method(:windows?)
    Shaka::ExecutableFile.define_singleton_method(:windows?) { true }
    yield
  ensure
    Shaka::ExecutableFile.define_singleton_method(:windows?, original)
  end

  def stopped_with(job)
    started = []
    replacing(:start_taskkill, ->(_pid) { started << [:taskkill] }) do
      Open3.popen3(RbConfig.ruby, '-e', 'sleep 120') do |input, _output, _error, waiter|
        input.close
        Shaka::LocalReviewWindowsTree.end_tree(waiter, job, seconds: 0.2)
      end
    end
    started
  end

  def with_stalled_taskkill
    Dir.mktmpdir('shaka-windows-taskkill') do |directory|
      stalled = File.join(directory, 'taskkill')
      File.write(stalled, "#!/bin/sh\ntouch '#{directory}/started'\nexec sleep 30\n", perm: 0o755)
      replacing(:taskkill, -> { stalled }) { yield File.join(directory, 'started') }
    end
  end

  def replacing(name, body)
    tree = Shaka::LocalReviewWindowsTree.singleton_class
    original = tree.instance_method(name)
    tree.define_method(name, &body)
    yield
  ensure
    tree.define_method(name, original)
  end
end
