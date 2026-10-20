# frozen_string_literal: true

require_relative 'session'
require_relative 'suite_pool'

# The regular Minitest suite, one file at a time, so a file that cannot load
# or does not exit is listed and the others still run.
class WindowsSuite < WindowsSession
  FILE_SECONDS = 90

  def call
    puts "suite workers=#{worker_count} file-timeout=#{FILE_SECONDS}s"
    @ok = WindowsSuitePool.new(self, workers: worker_count, seconds: FILE_SECONDS).run(suite_files)
    self
  end

  def suite_child_env = { 'BUNDLE_GEMFILE' => File.join(root, 'Gemfile') }

  def suite_file_command(file) = [bundle_command, 'exec', RbConfig.ruby, '-Itest', file]

  private

  def worker_count
    count = Integer(ENV.fetch('SHAKA_TEST_WORKERS', '2'))
    [count, 1].max
  end

  def suite_files = Dir.glob('test/**/*_test.rb', base: root).sort
end
