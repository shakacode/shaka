# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/local_review/process'

# Native Windows has no process groups, so a reviewer or its Git starts in Shaka's own group and
# a job object ends it. These run the Windows branch here; the hosted windows job runs it for real.
class WindowsLocalReviewTest < Minitest::Test
  def setup
    @windows = Shaka::LocalReviewProcess.windows
    @stop_seconds = Shaka::LocalReviewWindowsTree.stop_seconds
    Shaka::LocalReviewProcess.windows = true
    Shaka::LocalReviewWindowsTree.stop_seconds = 0.5
  end

  def teardown
    Shaka::LocalReviewProcess.windows = @windows
    Shaka::LocalReviewWindowsTree.stop_seconds = @stop_seconds
  end

  def test_capture_starts_without_a_process_group
    script = 'print $stdin.read.upcase, " ", Process.respond_to?(:getpgid) ? Process.getpgid(0) : 0; exit 3'
    output, _error, status = capture([script], stdin_data: 'diff', timeout: 30)

    assert_equal 3, status.exitstatus
    text, group = output.split
    assert_equal 'DIFF', text
    assert_equal Process.getpgid(0), Integer(group) unless windows_host?
  end

  # Git's blob sizes count bytes, so a Windows text-mode pipe that rewrote line endings broke the
  # commit export on the hosted job.
  def test_capture_passes_line_endings_through_both_ways
    script = '$stdin.binmode; $stdout.binmode; print $stdin.read.bytesize, "|a\\r\\nb\\n"'
    output, _error, status = capture([script], stdin_data: "x\ny\n", timeout: 30)

    assert_predicate status, :success?
    assert_equal "4|a\r\nb\n", output
  end

  # Off Windows neither a job nor taskkill exists, as when both fail there, so only the direct
  # termination can end the leader.
  def test_timeout_ends_a_leader_that_outlasts_the_job_and_taskkill
    started = clock
    _output, _error, status = capture(['sleep 120'], stdin_data: nil, timeout: 1)

    assert_nil status
    assert_operator clock - started, :<, 30
  end

  # The leader has exited and been reaped, so its pid may already name an unrelated process.
  def test_drain_timeout_sends_nothing_to_the_reaped_leader
    signals = with_recorded_kills do
      _output, _error, status = capture([LEAVE_DESCENDANT, pid_file], stdin_data: nil, timeout: 30)

      assert_instance_of Shaka::LocalReviewProcess::DrainTimeout, status
    end

    assert_empty signals
  ensure
    end_descendant
  end

  # Only the job still names a descendant whose leader exited, as a reviewer's helper can be.
  def test_windows_drain_timeout_ends_the_descendant
    skip 'needs Windows job objects' unless windows_host?

    _output, _error, status = capture([LEAVE_DESCENDANT, pid_file], stdin_data: nil, timeout: 30)

    assert_instance_of Shaka::LocalReviewProcess::DrainTimeout, status
    refute running?(Integer(File.read(pid_file))), 'the descendant outlived the stop'
  end

  LEAVE_DESCENDANT = <<~RUBY
    pid = spawn(RbConfig.ruby, '-e', 'sleep 120')
    File.write(ARGV.fetch(0), pid.to_s)
  RUBY

  private

  def capture(script, stdin_data:, timeout:)
    Shaka::LocalReviewProcess.capture([RbConfig.ruby, '-e', *script], stdin_data:, chdir: Dir.tmpdir, timeout:)
  end

  def pid_file = @pid_file ||= File.join(Dir.mktmpdir('shaka-windows-review'), 'pid')

  def end_descendant
    Process.kill('KILL', Integer(File.read(pid_file))) if File.file?(pid_file)
  rescue Errno::ESRCH
    nil
  end

  # Off Windows the descendant survives the stop, so its readers fail once the pipes close.
  def with_recorded_kills(&)
    signals = []
    reporting = Thread.report_on_exception
    Thread.report_on_exception = false
    tree = Shaka::LocalReviewWindowsTree.singleton_class
    replacing(Process.singleton_class, :kill, ->(*call) { signals << call }) do
      replacing(tree, :start_taskkill, ->(pid) { signals << [:taskkill, pid] }, &)
    end
    signals
  ensure
    Thread.report_on_exception = reporting
  end

  def replacing(owner, name, body)
    original = owner.instance_method(name)
    owner.define_method(name, &body)
    yield
  ensure
    owner.define_method(name, original)
  end

  def running?(pid)
    deadline = clock + 5
    loop do
      Process.kill(0, pid)
      return true if clock > deadline

      sleep 0.2
    end
  rescue Errno::ESRCH
    false
  end

  def windows_host? = Shaka::ExecutableFile.windows?

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
