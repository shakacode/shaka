# frozen_string_literal: true

require_relative 'doctor_companion_skills_support'

# A folder or plugin record doctor cannot read degrades the check; it never raises or reads as healthy.
class DoctorCompanionSkillsFaultsTest < Minitest::Test
  include CompanionSkillsSupport

  def test_a_bad_plugin_path_is_reported_not_raised
    plugin('pack', skills: [], install: "/bad\u0000path")
    assert_includes report, '[DEGRADED] Companion skills — Claude Code plugin skills not read'
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
