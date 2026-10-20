# frozen_string_literal: true

require 'tmpdir'
require_relative 'session'

# shaka doctor and the bounded command it uses to start checks.
class WindowsDoctor < WindowsSession
  def call
    record('doctor through the shaka helper') { helper }
    record('bounded command answers') { short_command }
    record('bounded command reaches its deadline') { deadline }
    record('doctor command tests') { ruby_tests('test/doctor_command_test.rb') }
    puts "WINDOWS doctor-orphan: #{orphan_label}"
    self
  end

  private

  def helper
    script = File.join(root, 'skills/shaka/scripts/shaka')
    stdout, stderr, status = capture([git_bash, script, 'doctor', '--root', root], 90)
    accept_report(stdout, stderr, status)
  end

  def accept_report(stdout, stderr, status)
    combined = "#{stdout}\n#{stderr}"
    raise "aborted while spawning: #{excerpt(combined)}" if combined.include?('wrong exec option symbol: pgroup')
    return puts("  exit #{status.exitstatus}") if stdout.include?('Shaka doctor:')

    raise "no report (exit #{status.exitstatus}): #{excerpt(combined)}"
  end

  def short_command
    out, err, ok = bounded(5).call([RbConfig.ruby, '-e', 'print "ok"'])
    return if ok && out == 'ok'

    raise "expected ok, got ok=#{ok} out=#{out.inspect} err=#{err.inspect}"
  end

  def deadline
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    out, err, ok = bounded(0.4).call([RbConfig.ruby, '-e', 'sleep 30'])
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    raise "command succeeded: out=#{out.inspect} err=#{err.inspect}" if ok
    raise "returned in #{format('%.2f', elapsed)}s, before the 0.4s deadline" if elapsed < 0.4
    raise "still running after #{format('%.2f', elapsed)}s" if elapsed > 8
  end

  def orphan_label
    orphan_descendant
    'PASS'
  rescue StandardError => e
    puts "#{e.class}: #{e.message}"
    'FAIL'
  end

  def orphan_descendant
    pid = nil
    Dir.mktmpdir do |dir|
      pid, ok, err = run_orphan(dir)
      raise "pid #{pid} still alive (command ok=#{ok}, err=#{err.inspect})" if pid && still_alive?(pid)

      puts "  descendant stopped (command ok=#{ok})"
    end
  ensure
    stop(pid) if pid && alive?(pid)
  end

  def run_orphan(dir)
    path = File.join(dir, 'pid')
    _out, err, ok = bounded(0.8).call([RbConfig.ruby, '-e', orphan_script(path)])
    pid = File.file?(path) ? Integer(File.read(path).strip) : nil
    [pid, ok, err]
  end

  def still_alive?(pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      return false unless alive?(pid)

      sleep 0.05
    end
    true
  end

  def orphan_script(path)
    'child = Process.spawn(RbConfig.ruby, "-e", "sleep 30", out: :out, err: :err); ' \
      "File.write(#{path.dump}, child.to_s); Process.detach(child); exit 0"
  end
end
