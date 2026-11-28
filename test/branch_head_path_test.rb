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

  # Naming a subdirectory or a symlink to the checkout still guards the whole worktree.
  def test_planted_git_is_skipped_from_a_subdirectory_or_symlinked_root
    link = File.join(@dir, 'link')
    File.symlink(@task, link)
    FileUtils.mkdir_p(File.join(@task, 'sub'))
    marker = plant_git
    [File.join(@task, 'sub'), link].each do |root|
      with_path("#{File.join(@task, 'bin')}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}") do
        assert_equal 'not_pushed', Shaka::BranchHead.new(root:).check['state'], root
      end
    end

    refute_path_exists marker
  end

  def test_no_git_outside_the_checkout_is_an_error
    plant_git
    error = assert_raises(Shaka::Error) { with_path(File.join(@task, 'bin')) { check } }

    assert_includes error.message, 'git is not on PATH outside the checkout'
  end

  # On a case-insensitive filesystem, a PATH entry spelled with other case is still the checkout.
  def test_planted_git_under_a_case_alias_never_runs
    alias_bin = File.join(File.dirname(@task), File.basename(@task).upcase, 'bin')
    marker = plant_git
    skip 'case-sensitive filesystem' unless File.directory?(alias_bin)

    with_path("#{alias_bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}") { check }

    refute_path_exists marker
  end

  private

  def plant_git
    marker = File.join(@dir, 'planted-ran')
    FileUtils.mkdir_p(File.join(@task, 'bin'))
    File.write(File.join(@task, 'bin', 'git'), "#!/bin/sh\ntouch '#{marker}'\nexit 1\n")
    File.chmod(0o755, File.join(@task, 'bin', 'git'))
    marker
  end

  def with_path(path)
    saved = ENV.fetch('PATH')
    ENV['PATH'] = path
    yield
  ensure
    ENV['PATH'] = saved
  end
end
