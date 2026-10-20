# frozen_string_literal: true

require 'tempfile'
require_relative 'session'

# The regular Minitest suite, minus files that cannot load on Windows.
# bin/run-tests requires every file in each worker, so one missing library
# aborts the suite before any example runs. Those files are printed as gaps.
# The file list goes through an env path: bundle.bat runs under cmd.exe, and
# cmd.exe rejects the command line when every test path is an argument.
class WindowsSuite < WindowsSession
  GAPS = {
    'test/local_evaluation_probe_container_test.rb' =>
      'requires pty, which Windows Ruby does not ship'
  }.freeze
  LAUNCH = "ARGV.replace(File.readlines(ENV.fetch('SHAKA_WINDOWS_SUITE_LIST'), chomp: true)); " \
           "load File.expand_path('bin/run-tests')"

  def call
    puts "suite workers=#{workers}"
    report_gaps
    @ok = run_suite == true
    self
  end

  private

  def workers = ENV.fetch('SHAKA_TEST_WORKERS', '2')

  def report_gaps
    GAPS.each { |file, reason| puts "WINDOWS suite gap: #{file} - #{reason}" }
  end

  def run_suite
    Tempfile.create('windows-suite') do |list|
      list.write("#{included_files.join("\n")}\n")
      list.close
      system(suite_env(list.path), *launch_command, chdir: root)
    end
  end

  def included_files = Dir.glob('test/**/*_test.rb', base: root).sort - GAPS.keys

  def launch_command = [bundle_command, 'exec', RbConfig.ruby, '-e', LAUNCH]

  def suite_env(list)
    { 'SHAKA_TEST_WORKERS' => workers, 'SHAKA_WINDOWS_SUITE_LIST' => list }
  end
end
