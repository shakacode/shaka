# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/doctor'

# The previous attempt at a deadline failed three ways at once: the block form of popen3
# joined the child during cleanup, output was read only after exit, and the test asserted
# no elapsed time so it passed while waiting the full thirty seconds. Each of those is a
# test here.
class DoctorCommandTest < Minitest::Test
  def test_a_command_that_never_answers_returns_at_its_deadline
    elapsed, (out, error, ok) = timed { run_bounded(0.2, %w[sleep 30]) }

    refute ok
    assert_operator elapsed, :<, 2, 'the deadline did not bound the wait'
    assert_empty out
    assert_includes error, '0.2'
  end

  # A killed child that is never reaped is a zombie, and Process.kill(0) still finds it.
  def test_a_timeout_leaves_no_surviving_child
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'pid')
      _out, _error, ok = run_bounded(0.2, ['sh', '-c', "echo $$ > #{path}; sleep 30"])
      refute ok

      refute_alive(pid_in(path), 'the child outlived its deadline')
    end
  end

  # The leader can exit and be reaped while a descendant holds the pipes open, so the group
  # must be addressed by the pid it was created with rather than looked up at expiry.
  def test_a_timeout_kills_a_descendant_that_outlived_the_leader
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'pid')
      _out, _error, ok = run_bounded(0.5, ['sh', '-c', "sh -c 'echo $$ > #{path}; sleep 30' &"])
      refute ok

      refute_alive(pid_in(path), 'a descendant outlived the deadline')
    end
  end

  # Reading only after the child exits deadlocks once it fills a pipe buffer.
  def test_output_larger_than_a_pipe_buffer_does_not_deadlock
    elapsed, (out, _error, ok) = timed { run_bounded(10, ['ruby', '-e', 'print "x" * 200_000']) }

    assert ok
    assert_equal 200_000, out.bytesize
    assert_operator elapsed, :<, 9, 'the read deadlocked until the deadline'
  end

  def test_a_command_that_answers_returns_its_streams_separately
    out, error, ok = run_bounded(10, ['sh', '-c', 'printf hello; printf oops >&2'])

    assert ok
    assert_equal 'hello', out
    assert_equal 'oops', error
  end

  def test_a_failing_command_reports_failure_with_its_error
    _out, error, ok = run_bounded(10, ['sh', '-c', 'echo bad >&2; exit 3'])

    refute ok
    assert_includes error, 'bad'
  end

  def test_the_child_runs_where_asked_without_moving_this_process
    Dir.mktmpdir do |dir|
      here = Dir.pwd
      out, _error, ok = run_bounded(10, %w[pwd], dir)

      assert ok
      assert_equal File.realpath(dir), File.realpath(out.strip)
      assert_equal here, Dir.pwd
    end
  end

  # checks.rb turns SystemCallError into that check's answer, so it must still arrive.
  def test_a_command_that_cannot_launch_raises_for_its_caller
    assert_raises(SystemCallError) { run_bounded(10, ['definitely-not-a-command-4f2d']) }
  end

  private

  def pid_in(path) = Integer(File.read(path).strip)

  # A killed process lingers until its parent reaps it, and a descendant is reparented before
  # init can, so the check waits for it to disappear instead of racing the teardown. A survivor
  # sleeps for thirty seconds and is still there when the wait runs out.
  def refute_alive(pid, message, within: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + within
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      return unless alive?(pid)

      sleep 0.05
    end
    flunk message
  end

  def alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def run_bounded(timeout, argv, chdir = nil)
    Shaka::Doctor::BoundedCommand.new(timeout: timeout).call(argv, chdir)
  end

  def timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    [Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, result]
  end
end
