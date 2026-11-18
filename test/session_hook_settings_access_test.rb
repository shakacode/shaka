# frozen_string_literal: true

require_relative 'official_install_support'
require 'shaka/install/session_hook'

# Settings Shaka cannot read or write skip the optional reminder; only an explicit --session-hook refuses them.
class SessionHookSettingsAccessTest < Minitest::Test
  include OfficialInstallSupport

  def teardown
    File.chmod(0o700, settings_folder) if File.directory?(settings_folder)
    super
  end

  def test_settings_that_cannot_be_read_skip_the_default_hook_and_stop_the_explicit_flag
    FileUtils.mkdir_p(settings_path)
    output, status = invoke('--repository', @remote, '--agent', 'claude', '--session-hook')
    refute_predicate status, :success?, output
    refute_path_exists File.join(@home, '.claude/skills/shaka')
    output, status = invoke('--repository', @remote, '--agent', 'claude')
    assert_predicate status, :success?, output
    assert_includes output, 'Skipped the Claude Code update-check hook'
  end

  def test_settings_that_cannot_be_written_skip_the_default_hook
    skip 'Requires a user subject to directory permissions' if Process.euid.zero?
    FileUtils.mkdir_p(settings_folder)
    File.write(settings_path, '{}')
    File.chmod(0o500, settings_folder)
    hook = Shaka::Install::SessionHook.new('/opt/skills/shaka/scripts/shaka', home: @home)
    assert_match(/\ASkipped /, hook.apply(true, strict: false))
    assert_raises(SystemCallError) { hook.apply(true) }
  end

  private

  def settings_folder = File.join(@home, '.claude')
  def settings_path = File.join(settings_folder, 'settings.json')
end
