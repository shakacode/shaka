# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'branch_head_fixture'

# The branch check often runs inside a candidate's checkout, so a git committed there must never run.
class BranchHeadPathTest < Minitest::Test
  include BranchHeadFixture

  def test_git_planted_in_the_checkout_never_runs
    marker = File.join(@dir, 'planted-ran')
    planted = File.join(@task, 'bin')
    FileUtils.mkdir_p(planted)
    File.write(File.join(planted, 'git'), "#!/bin/sh\ntouch '#{marker}'\nexit 1\n")
    File.chmod(0o755, File.join(planted, 'git'))
    state = with_path("#{planted}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}") { check['state'] }

    assert_equal 'not_pushed', state
    refute_path_exists marker
  end

  private

  def with_path(path)
    saved = ENV.fetch('PATH')
    ENV['PATH'] = path
    yield
  ensure
    ENV['PATH'] = saved
  end
end
