# frozen_string_literal: true

require_relative 'doctor_companion_skills_support'

# A folder or plugin record doctor cannot read degrades the check; it never raises or reads as healthy.
class DoctorCompanionSkillsFaultsTest < Minitest::Test
  include CompanionSkillsSupport

  def test_a_bad_plugin_path_still_checks_the_other_plugins
    skill('.claude/skills/review')
    plugin('bad', skills: [], install: "/bad\u0000path")
    plugin('pack', skills: %w[review])
    text = report
    assert_includes text, 'bad plugin skills not read'
    assert_includes text, 'review (~/.claude/skills, pack plugin)'
  end

  def test_a_link_into_an_unreadable_folder_is_not_called_broken
    @locked = File.join(@home, 'locked')
    FileUtils.mkdir_p(File.join(@locked, 'skill'))
    FileUtils.mkdir_p(File.join(@home, '.agents/skills'))
    File.symlink(File.join(@locked, 'skill'), File.join(@home, '.agents/skills/skill'))
    File.chmod(0o000, @locked)
    skip 'this account reads unreadable folders' if File.readable?(@locked)

    text = report
    assert_includes text, '~/.agents/skills/skill not read: Permission denied'
    refute_includes text, 'point nowhere'
  end

  def test_an_unreadable_folder_keeps_the_other_results
    FileUtils.mkdir_p(File.join(@home, '.cursor/skills'))
    File.symlink(File.join(@home, 'missing'), File.join(@home, '.cursor/skills/gone'))
    @locked = File.join(@home, '.agents/skills')
    FileUtils.mkdir_p(@locked)
    File.chmod(0o000, @locked)
    skip 'this account reads unreadable folders' if File.readable?(@locked)

    text = report
    assert_includes text, '~/.agents/skills not read'
    assert_includes text, '~/.cursor/skills/gone'
  end

  def test_unreadable_plugin_settings_are_reported_not_raised
    write('.claude/plugins/installed_plugins.json', '{not json')
    text = report
    assert_includes text, '[DEGRADED] Companion skills — Claude Code plugin skills not read'
    refute_includes text, '[FAILED]'
  end

  def test_unreachable_plugin_settings_are_not_called_healthy
    skill('.claude/skills/review')
    plugin('pack', skills: %w[review])
    @locked = File.join(@home, '.claude/plugins')
    File.chmod(0o000, @locked)
    skip 'this account reads unreadable folders' if File.readable?(@locked)

    assert_includes report, '[DEGRADED] Companion skills — Claude Code plugin skills not read: Permission denied'
  end

  def test_a_missing_home_is_reported_not_raised
    assert_includes doctor(home: nil).first, '[DEGRADED] Companion skills — not checked: no home directory'
  end
end
