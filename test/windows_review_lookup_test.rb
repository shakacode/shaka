# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/local_review/path_guard'

# Windows installs Git and reviewer CLIs as NAME.exe, which local review now finds.
class WindowsReviewLookupTest < Minitest::Test
  def test_lookup_accepts_only_an_exe_beside_the_bare_name
    guard = Shaka::LocalReviewPathGuard

    assert_equal %w[git git.exe], guard.file_names('git', windows: true)
    assert_equal %w[git.exe], guard.file_names('git.exe', windows: true)
    assert_equal %w[git], guard.file_names('git', windows: false)
  end

  def test_lookup_finds_a_reviewer_installed_as_an_exe
    Dir.mktmpdir('shaka-windows-path') do |directory|
      %w[claude.exe claude.cmd].each { |name| File.write(File.join(directory, name), 'MZ') }
      File.chmod(0o755, File.join(directory, 'claude.exe'))
      found = on_windows { Shaka::LocalReviewPathGuard.safe_executable(directory, 'claude', Dir.mktmpdir) }

      assert_equal File.join(File.expand_path(directory), 'claude.exe'), found
    end
  end

  def test_windows_ownership_ignores_case_and_separators
    owned = Shaka::LocalReviewExecutable

    assert owned.candidate_owned?('C:\\Repo\\bin\\claude.exe', 'c:/repo', windows: true)
    refute owned.candidate_owned?('C:/Repo/bin/claude.exe', 'c:/repo', windows: false)
    refute owned.candidate_owned?('C:/Repository/claude.exe', 'c:/repo', windows: true)
  end

  # The lookup stops at the first match, so a later PATH entry that cannot expand never matters.
  def test_lookup_stops_before_a_later_entry_that_cannot_expand
    skip 'needs /bin/sh' unless File.executable?('/bin/sh')

    assert_equal '/bin/sh', Shaka::LocalReviewPathGuard.safe_executable('/bin:~nosuchuser', 'sh', Dir.tmpdir)
  end

  private

  # Ruby on this host reports Windows for the block, so lookup tries NAME.exe.
  def on_windows
    original = Shaka::ExecutableFile.method(:windows?)
    Shaka::ExecutableFile.define_singleton_method(:windows?) { true }
    yield
  ensure
    Shaka::ExecutableFile.define_singleton_method(:windows?, original)
  end
end
