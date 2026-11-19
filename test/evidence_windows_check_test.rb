# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/evidence/candidate_tree'
require 'shaka/evidence/tree_watch'
require 'shaka/evidence/windows_check'

# Processes and probes for the Windows check tests.
module WindowsCheckFixture
  # Sleeps first so the job holds the leader before it starts its descendant, then exits and leaves
  # the descendant holding the output, as a test runner's worker can. The descendant exits on its own:
  # killing it by a saved ID could reach another process once Windows reuses that ID.
  LEADER_EXITS = <<~RUBY
    sleep 1
    pid = spawn(RbConfig.ruby, '-e', 'sleep 30')
    File.write(ARGV.fetch(0), pid.to_s)
  RUBY
  SLEEPER = [RbConfig.ruby, '-e', 'sleep 120'].freeze
  NO_JOB = ->(_pid) {}
  LIMITATION = Shaka::Evidence::WindowsCheck::LIMITATION

  def check(command, root, **)
    @checks << Shaka::Evidence::WindowsCheck.new(command, root:, **)
    @checks.last
  end

  def setup = @checks = []

  def teardown
    @checks.each { |check| check.close(finished: true) }
  end

  def recording_kills
    kills = []
    original = Process.method(:kill)
    Process.define_singleton_method(:kill) { |*arguments| kills << arguments }
    yield
    kills
  ensure
    Process.define_singleton_method(:kill, original)
  end

  # A process ended through its job can take a moment to go, so only one alive for 5 seconds counts.
  def running?(pid)
    deadline = now + 5
    loop do
      Process.kill(0, pid)
      return true if now > deadline

      sleep 0.2
    end
  rescue Errno::ESRCH
    false
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# How a Windows check stops. With a job, the job ends the check and every process it started. Without
# one, only a leader Ruby has not reaped is ended, through the handle Ruby still holds, and the stop
# reports that other processes may still be running. Tests needing a real job run only on Windows;
# the rest run everywhere, since the no-job path uses only Ruby's process calls.
class EvidenceWindowsCheckStopTest < Minitest::Test
  include WindowsCheckFixture

  def test_without_a_job_stop_ends_a_live_leader_and_reports_the_limit
    Dir.mktmpdir('shaka-windows-check') do |root|
      started = check(SLEEPER, root, job: NO_JOB)

      assert_equal LIMITATION, started.stop
      refute_predicate started.waiter, :alive?
    end
  end

  # Once Ruby has reaped the leader its ID may belong to another process, so nothing is signaled.
  def test_without_a_job_stop_leaves_an_exited_leader_alone
    with_descendant(job: NO_JOB) do |started, descendant|
      assert_empty(recording_kills { started.stop })
      assert_equal LIMITATION, started.limitation
      assert running?(descendant), 'without a job the descendant is left alone and reported'
    end
  end

  # A job Windows failed to terminate proves nothing, so the leader is ended by its handle and reported.
  def test_failed_job_termination_ends_the_leader_and_reports_the_limit
    failed = Struct.new(:terminate, :close).new(false, nil)
    Dir.mktmpdir('shaka-windows-check') do |root|
      started = check(SLEEPER, root, job: ->(_pid) { failed })

      assert_equal LIMITATION, started.stop
      refute_predicate started.waiter, :alive?
    end
  end

  # wait2 has released the handle, but the waiter thread has not exited yet.
  def test_reaped_leader_is_not_signaled_while_the_waiter_still_runs
    entered = Queue.new
    release = Queue.new
    Dir.mktmpdir('shaka-windows-check') do |root|
      started = check([RbConfig.ruby, '-e', 'exit 0'], root, job: NO_JOB, after_reap: holding(entered, release))
      entered.pop

      assert_predicate started.waiter, :alive?
      assert_empty(recording_kills { started.send(:end_leader) })
    ensure
      release << :go
    end
  end

  # A failed wait may have released the handle too.
  def test_leader_is_not_signaled_after_a_failed_wait
    Dir.mktmpdir('shaka-windows-check') do |root|
      started = failing_wait { check(SLEEPER, root, job: NO_JOB) }

      assert_empty(recording_kills { started.send(:end_leader) })
    ensure
      end_leader_directly(started)
    end
  end

  def test_with_a_job_stop_ends_a_descendant_after_its_leader_exits
    skip 'needs Windows job objects' unless Shaka::ExecutableFile.windows?

    with_descendant do |started, descendant|
      assert_nil started.stop
      refute running?(descendant), 'the job left the descendant running'
    end
  end

  def test_with_a_job_stop_ends_a_live_leader
    skip 'needs Windows job objects' unless Shaka::ExecutableFile.windows?

    Dir.mktmpdir('shaka-windows-check') do |root|
      started = check(SLEEPER, root)

      assert_nil started.stop
      refute_predicate started.waiter, :alive?
    end
  end

  private

  # Holds the waiter after it reaped the leader until RELEASE receives a value.
  def holding(entered, release)
    lambda do
      entered << :reaped
      release.pop
    end
  end

  def with_descendant(**)
    Dir.mktmpdir('shaka-windows-check') do |root|
      pid_file = File.join(root, 'descendant')
      started = check([RbConfig.ruby, '-e', LEADER_EXITS, pid_file], root, **)
      started.waiter.join(30)
      yield started, Integer(File.read(pid_file))
    end
  end

  # Builds the check while wait2 fails, and returns once its waiter has stopped on that failure.
  def failing_wait
    original = Process.method(:wait2)
    reporting = Thread.report_on_exception
    Thread.report_on_exception = false
    Process.define_singleton_method(:wait2) { |*| raise Errno::ECHILD }
    yield.tap { |started| assert_raises(Errno::ECHILD) { started.waiter.value } }
  ensure
    Process.define_singleton_method(:wait2, original)
    Thread.report_on_exception = reporting
  end

  def end_leader_directly(started)
    return unless started

    Process.kill('KILL', started.pid)
    Process.wait(started.pid)
  end
end

# How a Windows check starts and what a stopped run reports.
class EvidenceWindowsCheckStartTest < Minitest::Test
  include WindowsCheckFixture

  # A start that fails after spawning ends and reaps the leader itself, so nothing is left running.
  def test_failed_start_ends_and_reaps_its_leader
    spawned = nil
    failing = lambda do |pid|
      spawned = pid
      raise 'no job'
    end
    Dir.mktmpdir('shaka-windows-check') do |root|
      assert_raises(RuntimeError) { Shaka::Evidence::WindowsCheck.new(SLEEPER, root:, job: failing) }
    end

    assert_raises(Errno::ECHILD) { Process.wait(spawned) }
  end

  # A leader that outlived its stop has no status yet, so the stopped run reports none.
  def test_stopped_windows_run_reports_no_status_for_a_surviving_leader
    leader = Thread.new { sleep }
    watch = Shaka::Evidence::TreeWatch.new([], root: Dir.pwd, tree: nil, windows: true)

    assert_nil watch.send(:status, leader, 'changed tree')
  ensure
    leader&.kill
  end
end

# An edit after the leader exits stops a Windows check through the watch, as evidence run does.
class EvidenceWindowsCheckWatchTest < Minitest::Test
  include WindowsCheckFixture

  def test_edit_stops_a_windows_check_through_the_watch
    with_repository do |root, pid_file|
      outcome = watch_with_edit(root, pid_file)

      assert_predicate outcome, :stopped?
      assert_stop_coverage(outcome, Integer(File.read(pid_file)))
    end
  end

  # An interrupt after the leader exits still stops the check, and reports what it could not end.
  def test_interrupt_after_the_leader_exits_still_stops_the_check
    with_repository do |root, pid_file|
      tree = Shaka::Evidence::CandidateTree.capture(root:)
      command = [RbConfig.ruby, '-e', LEADER_EXITS, pid_file]
      watch = Shaka::Evidence::TreeWatch.new(command, root:, tree:, interval: 60, windows: true)
      _output, error = capture_io { interrupt_after_leader_exits(watch, pid_file) }

      assert_stop_report(error, Integer(File.read(pid_file)))
    end
  end

  private

  def interrupt_after_leader_exits(watch, pid_file)
    runner = Thread.new { watch.run }
    runner.report_on_exception = false
    sleep 0.05 until File.size?(pid_file) && watch.instance_variable_get(:@check)
    watch.instance_variable_get(:@check).waiter.join(30)
    runner.raise(Interrupt)
    assert_raises(Interrupt) { runner.join }
  end

  def assert_stop_report(error, descendant)
    if Shaka::ExecutableFile.windows?
      refute_includes error, LIMITATION
      refute running?(descendant), 'the job left the descendant running'
    else
      assert_includes error, LIMITATION
    end
  end

  # On Windows the job ends the descendant; elsewhere no job exists, so the limit is reported.
  def assert_stop_coverage(outcome, descendant)
    if Shaka::ExecutableFile.windows?
      refute outcome.stop_fields.key?('stop_limitation')
      refute running?(descendant), 'the job left the descendant running'
    else
      assert_equal LIMITATION, outcome.stop_fields.fetch('stop_limitation')
    end
  end

  def with_repository
    Dir.mktmpdir('shaka-windows-watch') do |root|
      git(root, 'init', '-q')
      File.write(File.join(root, 'tracked.txt'), "one\n")
      git(root, 'add', '-A')
      git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q', '-m', 'start')
      Dir.mktmpdir('shaka-windows-pid') { |directory| yield root, File.join(directory, 'descendant') }
    end
  end

  def watch_with_edit(root, pid_file)
    tree = Shaka::Evidence::CandidateTree.capture(root:)
    editor = Thread.new { edit_when_started(pid_file, File.join(root, 'edited.txt')) }
    command = [RbConfig.ruby, '-e', LEADER_EXITS, pid_file]
    Shaka::Evidence::TreeWatch.new(command, root:, tree:, interval: 0.2, windows: true).run
  ensure
    editor&.join
  end

  def edit_when_started(pid_file, path)
    deadline = now + 60
    sleep 0.05 until File.size?(pid_file) || now > deadline
    File.write(path, "edit\n")
  end

  def git(root, *arguments)
    output, status = Open3.capture2e('git', '-C', root, *arguments)
    raise "git #{arguments.first} failed: #{output}" unless status.success?
  end
end
