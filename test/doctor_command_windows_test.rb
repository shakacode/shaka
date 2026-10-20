# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_command_helper'

# The deadline without a process group. Windows Ruby rejects `pgroup`, so these
# are the checks that used to abort doctor before a command ran.
class DoctorCommandWindowsTest < Minitest::Test
  include DoctorCommandHelper

  def setup
    super
    skip 'process groups cover this' if Shaka::Doctor::BoundedCommand.process_groups?
  end

  def test_a_timeout_returns_without_process_groups
    elapsed, (out, error, ok) = timed { run_bounded(0.2, ['ruby', '-e', 'sleep 30']) }

    refute ok
    assert_operator elapsed, :<, 5, 'the configured deadline was not closely honored'
    assert_operator elapsed, :>=, 0.2, 'the command gave up before its deadline'
    assert_empty out
    assert_includes error, '0.2'
  end

  def test_a_timeout_leaves_no_surviving_child_without_process_groups
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'pid')
      _out, _error, ok = run_bounded(0.3, ['ruby', '-e', leader_script(path)])
      refute ok

      refute_alive(pid_in(path), 'expiry left the child running')
    end
  end

  def test_a_timeout_kills_a_descendant_without_process_groups
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'pid')
      _out, _error, ok = run_bounded(0.5, ['ruby', '-e', descendant_script(path, 'sleep 30')])
      refute ok

      refute_alive(pid_in(path), 'a descendant outlived the deadline')
    end
  end

  # taskkill /PID cannot see a descendant after the leader exits. The job assigned at
  # spawn still contains it, and ending that job is what stops it.
  def test_a_timeout_kills_a_descendant_whose_leader_already_exited
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'pid')
      _out, _error, ok = run_bounded(0.5, ['ruby', '-e', orphan_script(path)])
      refute ok

      refute_alive(pid_in(path), 'a descendant survived the leader exiting')
    end
  end

  def test_an_interrupted_call_does_not_strand_its_child_without_process_groups
    command = InterruptedCommand.new(timeout: 30)

    assert_raises(Interrupt) { command.call(['ruby', '-e', 'sleep 30']) }
    refute_alive(command.spawned, 'an interrupted call stranded its child')
  end

  def test_a_command_that_answers_returns_its_streams_separately_without_process_groups
    out, error, ok = run_bounded(10, ['ruby', '-e', 'print "hello"; $stderr.print "oops"'])

    assert ok
    assert_equal 'hello', out
    assert_equal 'oops', error
  end

  def test_the_child_runs_where_asked_without_process_groups
    Dir.mktmpdir do |dir|
      here = Dir.pwd
      out, _error, ok = run_bounded(10, ['ruby', '-e', 'print Dir.pwd'], dir)

      assert ok
      assert_equal File.realpath(dir), File.realpath(out.strip)
      assert_equal here, Dir.pwd
    end
  end

  private

  def leader_script(path) = "File.write(#{path.dump}, Process.pid.to_s); sleep 30"

  def descendant_script(path, follow)
    'child = Process.spawn(RbConfig.ruby, "-e", "sleep 30"); ' \
      "File.write(#{path.dump}, child.to_s); Process.detach(child); #{follow}"
  end

  def orphan_script(path)
    'child = Process.spawn(RbConfig.ruby, "-e", "sleep 30", out: :out, err: :err); ' \
      "File.write(#{path.dump}, child.to_s); Process.detach(child); exit 0"
  end
end
