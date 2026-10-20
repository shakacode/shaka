# frozen_string_literal: true

require_relative 'session'

# The regular Minitest suite. A failure here is a Windows gap, not a skipped file.
class WindowsSuite < WindowsSession
  def call
    workers = ENV.fetch('SHAKA_TEST_WORKERS', '2')
    puts "suite workers=#{workers}"
    command = shell_command(bundle_command, 'exec', RbConfig.ruby, 'bin/run-tests')
    @ok = system(suite_env(workers), *command, chdir: root) == true
    self
  end

  private

  def suite_env(workers) = { 'SHAKA_TEST_WORKERS' => workers }
end
