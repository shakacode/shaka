# frozen_string_literal: true

require_relative 'test_helper'
require 'shellwords'

# Windows test runs start the helper through shaka_command's Ruby argv instead of the sh launcher.
class ShakaCommandTest < Minitest::Test
  LAUNCHER = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_windows_argv_matches_the_launcher_exec_line
    exec_line = File.readlines(LAUNCHER, chomp: true).grep(/\Aexec /).last
    scripts = File.dirname(LAUNCHER)
    expected = exec_line.shellsplit[2..-2].map { it.sub('$scripts', scripts) }

    assert_equal expected, shaka_command(LAUNCHER, windows: true).drop(1)
  end

  def test_windows_argv_starts_the_helper
    output, status = Open3.capture2e(*shaka_command(LAUNCHER, windows: true), '--help')

    assert_predicate status, :success?, output
    assert_includes output, 'Usage: shaka'
  end
end
