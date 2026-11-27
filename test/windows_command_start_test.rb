# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/executable_file'
require 'shaka/evidence/timed_check'
require 'shaka/evidence/tree_watch'
require 'shaka/install/release_checkout'
require 'shaka/install/source'

# Native Windows starts a repository command through Git's sh, runs a check without a process
# group, and cannot read an execute bit from the file system. These run the Windows branches
# here; the hosted windows job runs them for real.
class WindowsCommandStartTest < Minitest::Test
  def test_script_command_runs_the_script_through_its_shebang
    Dir.mktmpdir('shaka-windows-command') do |directory|
      script = File.join(directory, 'check')
      File.binwrite(script, "#!/usr/bin/env ruby\nputs ARGV.join('|')\n")
      File.chmod(0o755, script)
      command = Shaka::ExecutableFile.script_command(script, shell: method(:shell), windows: true)
      output, status = Open3.capture2(*command, 'one two', '$HOME')

      assert_predicate status, :success?
      assert_equal "one two|$HOME\n", output
    end
  end

  def test_script_command_starts_the_script_itself_elsewhere
    assert_equal ['/repo/.agents/shaka/bin/test'],
                 Shaka::ExecutableFile.script_command('/repo/.agents/shaka/bin/test', shell: nil, windows: false)
  end

  def test_tree_watch_runs_a_windows_check_to_its_exit_status
    Dir.mktmpdir('shaka-windows-watch') do |root|
      watch = Shaka::Evidence::TreeWatch.new([RbConfig.ruby, '-e', 'exit 3'], root:, tree: nil, windows: true)

      assert_equal 3, watch.run.status.exitstatus
    end
  end

  # Git's sh is refused when it resolves into the checkout, as git.exe already is.
  def test_git_shell_refuses_an_sh_inside_the_checkout
    skip 'Windows runners may lack the symlink privilege' if Shaka::ExecutableFile.windows?

    Dir.mktmpdir('shaka-windows-shell') do |directory|
      checkout = File.join(directory, 'checkout')
      FileUtils.mkdir_p([checkout, File.join(directory, 'git/bin')])
      File.write(File.join(checkout, 'sh.exe'), '')
      File.symlink(File.join(checkout, 'sh.exe'), File.join(directory, 'git/bin/sh.exe'))

      error = assert_raises(Shaka::Error) { Shaka::Evidence::TimedCheck.trusted_shell(File.join(directory, 'git'), checkout) }
      assert_match(/resolves inside the checkout/, error.message)
    end
  end

  # Only Windows clones override line endings; elsewhere the user's Git settings stay in charge.
  def test_installer_clones_set_line_endings_only_on_windows
    assert_includes Shaka::Install::ReleaseCheckout.clone_config(windows: true), 'core.eol=lf'
    assert_empty Shaka::Install::ReleaseCheckout.clone_config(windows: false)
  end

  def test_windows_install_accepts_an_executable_record_without_an_execute_bit
    with_helper_without_execute_bit do |source, path|
      tracked = { 'skills/shaka/scripts/shaka' => %w[100755 blob] }

      assert source.send(:matching_modes?, tracked, windows: true)
      refute source.send(:matching_modes?, { 'skills/shaka/scripts/shaka' => %w[120000 blob] }, windows: true),
             'a symlink written out as a plain file matched'
      refute source.send(:matching_modes?, tracked, windows: false) unless Shaka::ExecutableFile.windows?
      File.chmod(0o646, path)
      refute source.send(:matching_modes?, tracked, windows: true) unless Shaka::ExecutableFile.windows?
    end
  end

  private

  # The real Git for Windows sh on Windows, where no /bin/sh exists.
  def shell = Shaka::ExecutableFile.windows? ? Shaka::Evidence::TimedCheck.git_shell(Dir.tmpdir) : '/bin/sh'

  def with_helper_without_execute_bit
    Dir.mktmpdir('shaka-windows-source') do |root|
      FileUtils.mkdir_p(File.join(root, 'skills/shaka/scripts'))
      path = File.join(root, 'skills/shaka/scripts/shaka')
      File.write(path, "#!/bin/sh\n")
      File.chmod(0o644, path)
      yield Shaka::Install::Source.new(root, ['shaka'], nil), path
    end
  end
end
