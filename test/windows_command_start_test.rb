# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/executable_file'
require 'shaka/evidence/timed_check'
require 'shaka/evidence/tree_watch'
require 'shaka/install/source'

# Native Windows starts a repository command through Git's sh, runs a check without a process
# group, and cannot read an execute bit from the file system. These run the Windows branches
# here; the hosted windows job runs them for real.
class WindowsCommandStartTest < Minitest::Test
  def test_script_command_runs_the_script_through_its_shebang
    Dir.mktmpdir('shaka-windows-command') do |directory|
      script = File.join(directory, 'check')
      File.binwrite(script, "#!/usr/bin/env ruby\nputs ARGV.join('|')\n")
      File.chmod(0o755, script)
      command = Shaka::ExecutableFile.script_command(script, shell: method(:shell), windows: true)
      output, status = Open3.capture2(*command, 'one two', '$HOME')

      assert_predicate status, :success?
      assert_equal "one two|$HOME\n", output
    end
  end

  def test_script_command_starts_the_script_itself_elsewhere
    assert_equal ['/repo/.agents/shaka/bin/test'],
                 Shaka::ExecutableFile.script_command('/repo/.agents/shaka/bin/test', shell: nil, windows: false)
  end

  def test_tree_watch_runs_a_check_without_a_process_group
    Dir.mktmpdir('shaka-windows-watch') do |root|
      watch = Shaka::Evidence::TreeWatch.new([RbConfig.ruby, '-e', 'exit 3'], root:, tree: nil, windows: true)

      assert_equal({}, watch.send(:group))
      assert_equal 3, watch.run.status.exitstatus
    end
  end

  # The leader exits at once and leaves a descendant holding the output, as a test runner's
  # worker can. Only the job still names that descendant.
  def test_windows_stop_ends_a_descendant_after_its_leader_exits
    skip 'needs Windows job objects' unless Shaka::ExecutableFile.windows?

    Dir.mktmpdir('shaka-windows-stop') do |root|
      pid_file = File.join(root, 'pid')
      stop_after_leader_exits(Shaka::Evidence::TreeWatch.new([], root:, tree: nil, windows: true), pid_file)

      refute running?(Integer(File.read(pid_file))), 'the descendant outlived the stop'
    end
  end

  # Off Windows neither a job nor taskkill exists, as when both fail there, so only the direct
  # termination can end the leader.
  def test_windows_stop_ends_a_leader_that_outlasts_the_job_and_taskkill
    Dir.mktmpdir('shaka-windows-stop') do |root|
      watch = Shaka::Evidence::TreeWatch.new([], root:, tree: nil, windows: true)
      Open3.popen3(RbConfig.ruby, '-e', 'sleep 120') do |input, _output, _error, waiter|
        input.close
        watch.send(:end_tree, waiter)

        refute_predicate waiter, :alive?
      end
    end
  end

  def test_windows_install_accepts_an_executable_record_without_an_execute_bit
    with_helper_without_execute_bit do |source, path|
      tracked = { 'skills/shaka/scripts/shaka' => %w[100755 blob] }

      assert source.send(:matching_modes?, tracked, windows: true)
      refute source.send(:matching_modes?, tracked, windows: false) unless Shaka::ExecutableFile.windows?
      File.chmod(0o646, path)
      refute source.send(:matching_modes?, tracked, windows: true) unless Shaka::ExecutableFile.windows?
    end
  end

  LEADER = <<~RUBY
    sleep 1
    pid = spawn(RbConfig.ruby, '-e', 'sleep 120')
    File.write(ARGV.fetch(0), pid.to_s)
  RUBY

  private

  def stop_after_leader_exits(watch, pid_file)
    Open3.popen3(RbConfig.ruby, '-e', LEADER, pid_file) do |input, _output, _error, waiter|
      input.close
      watch.instance_variable_set(:@job, watch.send(:adopt, waiter.pid))
      waiter.join(30)
      watch.send(:end_tree, waiter)
    end
  end

  def running?(pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      Process.kill(0, pid)
      return true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.2
    end
  rescue Errno::ESRCH
    false
  end

  # The real Git for Windows sh on Windows, where no /bin/sh exists.
  def shell = Shaka::ExecutableFile.windows? ? Shaka::Evidence::TimedCheck.git_shell(Dir.tmpdir) : '/bin/sh'

  def with_helper_without_execute_bit
    Dir.mktmpdir('shaka-windows-source') do |root|
      FileUtils.mkdir_p(File.join(root, 'skills/shaka/scripts'))
      path = File.join(root, 'skills/shaka/scripts/shaka')
      File.write(path, "#!/bin/sh\n")
      File.chmod(0o644, path)
      yield Shaka::Install::Source.new(root, ['shaka'], nil), path
    end
  end
end
