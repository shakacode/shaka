# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'
require_relative 'test_helper'
require_relative 'doctor_helper'

# Doctor names skills one coding agent loads twice and skill links that point nowhere,
# without changing any skill folder.
class DoctorCompanionSkillsTest < Minitest::Test
  include DoctorHelper

  def setup
    @home = Dir.mktmpdir('doctor-skills')
  end

  def teardown
    FileUtils.remove_entry(@home)
  end

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

  def test_a_long_list_is_shortened
    FileUtils.mkdir_p(File.join(@home, '.agents/skills'))
    7.times { |index| File.symlink(File.join(@home, "missing#{index}"), File.join(@home, ".agents/skills/s#{index}")) }
    assert_includes report, 's4, and 2 more'
  end

  def test_unreadable_plugin_settings_are_reported_not_raised
    write('.claude/plugins/installed_plugins.json', '{not json')
    text = report
    assert_includes text, '[DEGRADED] Companion skills — Claude Code plugin skills not read'
    refute_includes text, '[FAILED]'
  end

  private

  def report = doctor(home: @home).first

  def skill(relative) = write(File.join(relative, 'SKILL.md'), "---\nname: #{File.basename(relative)}\n---\n")

  def write(relative, text)
    path = File.join(@home, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  def plugin(name, skills:, enabled: true, scope: 'user')
    install = File.join(@home, '.claude/plugins/cache/market', name)
    skills.each { |skill_name| skill(File.join(install.delete_prefix("#{@home}/"), 'skills', skill_name)) }
    key = "#{name}@market"
    entry = [{ 'scope' => scope, 'installPath' => install }]
    update('.claude/plugins/installed_plugins.json', 'plugins') { |all| all.merge(key => entry) }
    update('.claude/settings.json', 'enabledPlugins') { |all| all.merge(key => enabled) }
  end

  def update(relative, field)
    path = File.join(@home, relative)
    data = File.file?(path) ? JSON.parse(File.read(path)) : {}
    data[field] = yield(data.fetch(field, {}))
    write(relative, JSON.generate(data))
  end
end
