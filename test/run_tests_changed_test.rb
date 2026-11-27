# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'

class RunTestsChangedTest < Minitest::Test
  def test_the_runner_runs_nothing_when_no_test_reads_the_change
    Dir.mktmpdir('run-tests-changed') do |root|
      commit_base(root)
      FileUtils.mkdir_p(File.join(root, 'internal'))
      File.write(File.join(root, 'internal/notes.md'), "# Notes\n")
      output, status = Open3.capture2e(RbConfig.ruby, File.join(root, 'bin/run-tests'), '--changed', 'main')

      assert_predicate status, :success?, output
      assert_equal "No test reads the changed files\n", output
    end
  end

  private

  def commit_base(root)
    %w[bin/run-tests test/support/changed_tests.rb].each do |path|
      FileUtils.mkdir_p(File.join(root, File.dirname(path)))
      FileUtils.cp(File.expand_path("../#{path}", __dir__), File.join(root, path))
    end
    [%w[init --quiet --initial-branch=main], %w[add .], %w[commit --quiet -m base]].each do |args|
      system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
             '-c', 'commit.gpgsign=false', *args, exception: true)
    end
  end
end
