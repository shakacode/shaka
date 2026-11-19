# frozen_string_literal: true

require_relative 'official_install_support'
require 'shaka/install/session_hook'

class InstallSessionHookTest < Minitest::Test
  include OfficialInstallSupport

  UNRELATED = { 'model' => 'opus',
                'hooks' => { 'SessionStart' => [{ 'matcher' => 'startup',
                                                  'hooks' => [{ 'type' => 'command', 'command' => 'mine' }] }],
                             'Stop' => [{ 'hooks' => [{ 'type' => 'command', 'command' => 'stop' }] }] } }.freeze

  # --session-hook was the opt-in before the hook became the default, so scripts that pass it keep working.
  def test_a_claude_install_adds_the_hook_beside_other_settings_and_later_runs_keep_it
    install_with_hook
    assert_equal UNRELATED, without_shaka
    [['--update'], %w[--agent claude --session-hook], %w[--agent codex]].each do |arguments|
      refute_includes installed(*arguments), 'update-check hook'
      assert_equal [helper_command], shaka_commands, arguments.inspect
    end
  end

  def test_reinstalling_with_the_opt_out_removes_only_the_hook
    install_with_hook
    assert_includes installed('--agent', 'claude', '--no-session-hook'), 'Removed the Claude Code update-check hook'
    assert_equal UNRELATED, settings
  end

  # The reminder is optional, so a default install finishes without it; an explicit --session-hook refuses first.
  def test_unreadable_settings_skip_the_default_hook_and_stop_the_explicit_flag
    write_settings('{ not json')
    output = refused('--repository', @remote, '--agent', 'claude', '--session-hook')
    assert_includes output, 'rerun bin/install without --session-hook'
    refute_path_exists File.join(@home, '.claude/skills/shaka')
    assert_includes installed('--repository', @remote, '--agent', 'claude'), 'Skipped the Claude Code update-check hook'
    assert_equal '{ not json', File.read(settings_path)
  end

  def test_only_claude_writes_settings_and_creates_them_when_missing
    %w[--session-hook --no-session-hook].each do |flag|
      assert_includes refused('--repository', @remote, '--agent', 'codex', flag), "#{flag} requires --agent claude"
    end
    installed('--repository', @remote, '--agent', 'codex')
    refute_path_exists settings_path
    assert_includes installed('--agent', 'claude'), 'Set the Claude Code update-check hook'
    assert_equal [helper_command], shaka_commands
  end

  def test_repeated_apply_changes_nothing_and_removal_drops_emptied_tables
    hook = Shaka::Install::SessionHook.new('/opt/shaka/skills/shaka/scripts/shaka', home: @home)
    assert_match(/\ASet /, hook.apply(true))
    assert_nil hook.apply(true)
    assert_match(/\ARemoved /, hook.apply(false))
    assert_empty(settings)
    assert_nil hook.apply(false)
  end

  def test_reinstall_from_a_moved_checkout_replaces_the_old_command
    Shaka::Install::SessionHook.new('/old/skills/shaka/scripts/shaka', home: @home).apply(true)
    Shaka::Install::SessionHook.new('/new place/skills/shaka/scripts/shaka', home: @home).apply(true)
    assert_equal ['/new\\ place/skills/shaka/scripts/shaka update-check --session-start'], shaka_commands
  end

  def test_unreadable_settings_refuse_the_flag_and_stay_untouched_without_it
    write_settings('{ not json')
    hook = Shaka::Install::SessionHook.new('/opt/skills/shaka/scripts/shaka', home: @home)
    error = assert_raises(ArgumentError) { hook.apply(true) }
    assert_includes error.message, 'Claude Code settings are not valid JSON'
    assert_includes error.message, 'rerun bin/install without --session-hook'
    assert_match(/\ASkipped /, hook.apply(true, strict: false))
    assert_nil hook.apply(false)
    assert_equal '{ not json', File.read(settings_path)
  end

  def test_a_linked_settings_file_stays_a_link
    real = File.join(@directory, 'dotfiles', 'settings.json')
    FileUtils.mkdir_p([File.dirname(real), File.dirname(settings_path)])
    File.write(real, JSON.generate(UNRELATED))
    File.symlink(real, settings_path)
    Shaka::Install::SessionHook.new('/opt/skills/shaka/scripts/shaka', home: @home).apply(true)
    assert File.symlink?(settings_path)
    assert_includes File.read(real), 'update-check'
  end

  private

  def settings_path = File.join(@home, '.claude/settings.json')
  def settings = JSON.parse(File.read(settings_path))

  def write_settings(value)
    FileUtils.mkdir_p(File.dirname(settings_path))
    File.write(settings_path, value.is_a?(String) ? value : JSON.generate(value))
  end

  def install_with_hook
    write_settings(UNRELATED)
    assert_includes installed('--repository', @remote, '--agent', 'claude'), 'Set the Claude Code update-check hook'
  end

  def installed(*)
    output, status = invoke(*)
    assert_predicate status, :success?, output
    output
  end

  def refused(*)
    output, status = invoke(*)
    refute_predicate status, :success?, output
    output
  end

  def helper_command
    "#{File.join(@home, '.claude/skills/shaka/scripts/shaka')} update-check --session-start"
  end

  def shaka_commands
    settings.dig('hooks', 'SessionStart').flat_map { it['hooks'] }
            .select { Shaka::Install::SessionHook.owned?(it) }.map { it['command'] }
  end

  def without_shaka
    copy = settings
    copy['hooks']['SessionStart'].reject! { |group| group['hooks'].any? { Shaka::Install::SessionHook.owned?(it) } }
    copy
  end
end
