# frozen_string_literal: true

require_relative 'doctor_companion_skills_support'

# Doctor names skills one coding agent loads twice and skill links that point nowhere,
# without changing any skill folder.
class DoctorCompanionSkillsTest < Minitest::Test
  include CompanionSkillsSupport

  def test_an_empty_home_is_healthy
    assert_includes report, '[HEALTHY] Companion skills — no duplicate names or broken links in 0 skill folder(s)'
  end

  # Installers link one skill into every agent's folder, and each agent reads only its own.

  def test_the_same_name_in_two_agents_folders_is_not_a_duplicate
    skill('.agents/skills/review')
    skill('.claude/skills/review')
    assert_includes report, '[HEALTHY] Companion skills — no duplicate names or broken links in 2 skill folder(s)'
  end

  def test_a_folder_skill_repeated_by_an_enabled_plugin_is_reported
    skill('.claude/skills/review')
    plugin('pack', skills: %w[review other])
    text = report
    assert_includes text, '[DEGRADED] Companion skills — Claude Code loads 1 skill name(s) twice: ' \
                          'review (~/.claude/skills, pack plugin)'
    assert_includes text, 'Keep one copy of each duplicated skill'
  end

  def test_a_disabled_or_project_plugin_is_ignored
    skill('.claude/skills/review')
    plugin('off', skills: %w[review], enabled: false)
    plugin('local', skills: %w[review], scope: 'project')
    assert_includes report, '[HEALTHY] Companion skills'
  end

  def test_a_broken_link_is_reported_and_left_in_place
    FileUtils.mkdir_p(File.join(@home, '.cursor/skills'))
    link = File.join(@home, '.cursor/skills/gone')
    File.symlink(File.join(@home, 'missing'), link)
    text = report
    assert_includes text, '[DEGRADED] Companion skills — 1 skill link(s) point nowhere: ~/.cursor/skills/gone'
    assert_includes text, 'Repoint or remove each broken link. Doctor changes nothing.'
    assert File.symlink?(link)
  end

  def test_a_skills_folder_that_is_a_broken_link_is_reported
    FileUtils.mkdir_p(File.join(@home, '.cursor'))
    File.symlink(File.join(@home, 'missing'), File.join(@home, '.cursor/skills'))
    assert_includes report, '1 skill link(s) point nowhere: ~/.cursor/skills'
  end

  def test_a_skill_md_link_that_points_nowhere_is_reported
    FileUtils.mkdir_p(File.join(@home, '.agents/skills/review'))
    File.symlink(File.join(@home, 'missing'), File.join(@home, '.agents/skills/review/SKILL.md'))
    assert_includes report, '1 skill link(s) point nowhere: ~/.agents/skills/review/SKILL.md'
  end

  def test_every_broken_link_is_named
    FileUtils.mkdir_p(File.join(@home, '.agents/skills'))
    7.times { |index| File.symlink(File.join(@home, "missing#{index}"), File.join(@home, ".agents/skills/s#{index}")) }
    expected = Array.new(7) { |index| "~/.agents/skills/s#{index}" }.join(', ')
    assert_includes report, "7 skill link(s) point nowhere: #{expected}"
  end

  # Claude Code loads only a folder holding SKILL.md, so these are no second copy.

  def test_a_broken_link_or_stray_entry_is_not_a_duplicate
    FileUtils.mkdir_p(File.join(@home, '.claude/skills/empty'))
    write('.claude/skills/notes', 'not a skill')
    File.symlink(File.join(@home, 'missing'), File.join(@home, '.claude/skills/review'))
    plugin('pack', skills: %w[review empty notes])
    text = report
    assert_includes text, '1 skill link(s) point nowhere: ~/.claude/skills/review'
    refute_includes text, 'twice'
  end
end
