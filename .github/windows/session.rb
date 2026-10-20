# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'timeout'

# Shared process helpers for the Windows exercise. Product code stays in lib/.
class WindowsSession
  def initialize(root)
    @root = root
    @ok = true
  end

  attr_reader :root

  def ok? = @ok

  def record(name)
    puts "== #{name}"
    yield
    puts "PASS #{name}"
  rescue StandardError => e
    @ok = false
    puts "FAIL #{name}: #{e.class}: #{e.message}"
  end

  def ruby_tests(*relative)
    files = relative.select { |file| File.file?(File.join(root, file)) }
    return puts('  no matching test files in this checkout') if files.empty?

    files.each { |file| run_one_test(file) }
  end

  def bundle_command
    bindir = RbConfig::CONFIG.fetch('bindir')
    names = %w[bundle bundle.cmd bundle.bat bundle.exe]
    names.map { |name| File.join(bindir, name) }.find { |path| File.file?(path) } || 'bundle'
  end

  def git_bash
    found = git_bash_candidates.find { |path| File.file?(path) }
    return found if found
    return 'bash' if system('bash', '-c', 'exit 0', out: File::NULL, err: File::NULL)

    raise 'Git bash is not installed on this runner'
  end

  def git_bash_candidates
    [
      File.join(ENV.fetch('ProgramFiles', 'C:/Program Files'), 'Git/bin/bash.exe'),
      'C:/Program Files/Git/bin/bash.exe'
    ]
  end

  def require_subject(feature)
    lib = File.join(root, 'skills/shaka/lib')
    $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
    require feature
  end

  def bounded(timeout)
    require_subject 'shaka/doctor/bounded_command'
    Shaka::Doctor::BoundedCommand.new(timeout:)
  end

  def capture(command, seconds)
    Timeout.timeout(seconds) { Open3.capture3(*command, chdir: root) }
  end

  def excerpt(text)
    text.to_s.lines.map(&:strip).reject(&:empty?).last(8).join(' | ')[0, 700]
  end

  def alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end

  def stop(pid)
    return taskkill(pid) if RUBY_PLATFORM.match?(/mswin|mingw/)

    Process.kill('KILL', pid)
  rescue StandardError
    nil
  end

  private

  def run_one_test(file)
    output, status = Open3.capture2e(test_env, *test_command(file), chdir: root)
    puts output
    raise "tests failed: #{file}" unless status.success?
  end

  def test_command(file) = shell_command(bundle_command, 'exec', RbConfig.ruby, '-Itest', file)

  def test_env = { 'BUNDLE_GEMFILE' => File.join(root, 'Gemfile') }

  # Windows runs `bundle` through a .bat file, which CreateProcess will not start.
  def shell_command(*argv)
    return argv unless windows?

    ['cmd.exe', '/d', '/c', argv.map { |arg| %("#{arg}") }.join(' ')]
  end

  def windows? = RUBY_PLATFORM.match?(/mswin|mingw/)

  def taskkill(pid)
    system('taskkill.exe', '/F', '/T', '/PID', pid.to_s, out: File::NULL, err: File::NULL)
  end
end
