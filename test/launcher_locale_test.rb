# frozen_string_literal: true

require_relative 'test_helper'
require 'shellwords'

# Without a locale, Ruby reads files and subprocess output as US-ASCII and fails on UTF-8 text.
class LauncherLocaleTest < Minitest::Test
  LAUNCHER = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  NO_LOCALE = { 'LANG' => nil, 'LC_ALL' => nil, 'LC_CTYPE' => nil }.freeze

  # Windows CreateProcess cannot start the sh launcher (#748); hosts there run it through Git Bash.
  def setup
    skip('Windows cannot start the sh launcher directly') if WINDOWS
    @directory = Dir.mktmpdir('launcher-locale')
  end

  def teardown = (FileUtils.remove_entry(@directory) if @directory)

  def test_helper_and_its_subprocesses_read_utf8_when_the_shell_sets_no_locale
    child = "print Encoding.default_external, ' ', IO.popen([#{RbConfig.ruby.dump}, '-e', " \
            "'print Encoding.default_external'], &:read)"
    output, status = launch(NO_LOCALE, "exec #{RbConfig.ruby.shellescape} -e #{child.shellescape}")
    assert_predicate status, :success?, output
    assert_equal 'UTF-8 UTF-8', output
  end

  def test_helper_keeps_a_chosen_locale
    output, status = launch(NO_LOCALE.merge('LC_ALL' => 'C'), 'printf "%s|%s" "${LANG-unset}" "$LC_ALL"')
    assert_predicate status, :success?, output
    assert_equal 'unset|C', output
  end

  private

  # SHAKA_RUBY stands in for Ruby, so the body observes the environment the launcher passes on.
  def launch(environment, body)
    ruby = File.join(@directory, 'ruby')
    File.write(ruby, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, ruby)
    Open3.capture2e(environment.merge('SHAKA_RUBY' => ruby), LAUNCHER, 'workflow', chdir: @directory)
  end
end
