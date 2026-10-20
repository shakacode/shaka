# frozen_string_literal: true

require_relative 'session'

# The regular Minitest suite, minus files that cannot load on Windows.
# bin/run-tests requires every file in each worker, so one missing library
# aborts the suite before any example runs. Those files are printed as gaps.
class WindowsSuite < WindowsSession
  GAPS = {
    'test/local_evaluation_probe_container_test.rb' =>
      'requires pty, which Windows Ruby does not ship'
  }.freeze

  def call
    workers = ENV.fetch('SHAKA_TEST_WORKERS', '2')
    puts "suite workers=#{workers}"
    GAPS.each { |file, reason| puts "WINDOWS suite gap: #{file} - #{reason}" }
    @ok = system(suite_env(workers), *command, chdir: root) == true
    self
  end

  private

  def command = [bundle_command, 'exec', RbConfig.ruby, 'bin/run-tests', *included_files]

  def included_files = Dir.glob('test/**/*_test.rb', base: root).sort - GAPS.keys

  def suite_env(workers) = { 'SHAKA_TEST_WORKERS' => workers }
end
