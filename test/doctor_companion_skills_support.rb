# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'
require_relative 'test_helper'
require_relative 'doctor_helper'

# A temporary home holding coding agents' skill folders and Claude Code plugin records.
module CompanionSkillsSupport
  include DoctorHelper

  def setup
    @home = Dir.mktmpdir('doctor-skills')
  end

  def teardown
    File.chmod(0o755, @locked) if @locked
    FileUtils.remove_entry(@home)
  end

  private

  def report = doctor(home: @home).first

  def skill(relative) = write(File.join(relative, 'SKILL.md'), "---\nname: #{File.basename(relative)}\n---\n")

  def write(relative, text)
    path = File.join(@home, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  def plugin(name, skills:, enabled: true, scope: 'user', install: nil)
    install ||= File.join(@home, '.claude/plugins/cache/market', name)
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
