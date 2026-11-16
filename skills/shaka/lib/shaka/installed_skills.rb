# frozen_string_literal: true

require 'json'
require_relative 'install/locations'

module Shaka
  # Finds the skills coding agents load from a home directory: each host's skills folder and
  # Claude Code's enabled user-scope plugins. Doctor and `shaka companions` share this scan.
  # A path this account cannot read is recorded in `unread`; the rest of the scan continues.
  class InstalledSkills
    # `origin` is the host key for a skills folder, or "NAME plugin" for a Claude Code plugin.
    # `revision` is the plugin record's commit or version; nil for a folder skill.
    Skill = Data.define(:name, :path, :origin, :revision)

    CLAUDE = Install::Locations::HOSTS.fetch('claude')
    PLUGINS = File.join('.claude', 'plugins', 'installed_plugins.json')
    SETTINGS = File.join('.claude', 'settings.json')

    attr_reader :unread

    def initialize(home:)
      @home = home
      @unread = []
    end

    # Every host's skills folder path, whether or not it exists.
    def host_paths = Install::Locations::HOSTS.transform_values { |relative| File.join(@home, relative) }

    # Every loadable skill: host folders first, then Claude Code plugins.
    def all
      folders = host_paths.filter_map do |host, folder|
        skills(folder).map { |path| Skill.new(File.basename(path), path, host, nil) } if File.directory?(folder)
      end
      folders.flatten + plugin_skills
    end

    # Skills in Claude Code's own folder and in its enabled plugins, which it loads side by side.
    def claude_skills
      folder = File.join(@home, CLAUDE)
      own = File.directory?(folder) ? skills(folder) : []
      own.map { |path| Skill.new(File.basename(path), path, 'claude', nil) } + plugin_skills
    end

    # An unreadable folder is named in the report; the other folders are still checked.
    def entries(folder)
      Dir.children(folder).reject { |name| name.start_with?('.') }.sort.map { |name| File.join(folder, name) }
    rescue SystemCallError => e
      @unread << "#{shown(folder)} not read: #{first_line(e.message)}"
      []
    end

    # Only a folder holding SKILL.md loads as a skill, so a broken link or stray file is no copy.
    def skills(folder) = entries(folder).select { |path| skill?(path) }

    def shown(path) = path.start_with?("#{@home}/") ? "~#{path.delete_prefix(@home)}" : path

    private

    def first_line(message) = message.lines.first.to_s.strip

    # A skill this account cannot read is named, so it never silently drops out of the comparison.
    def skill?(path)
      File.stat(File.join(path, 'SKILL.md')).file?
    rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ELOOP
      false
    rescue SystemCallError => e
      @unread << "#{shown(path)} not read: #{first_line(e.message)}"
      false
    end

    def plugin_skills
      @plugin_skills ||= begin
        found = []
        enabled_plugins.each { |key, installs| add_plugin(found, plugin(key), installs) }
        found
      rescue JSON::ParserError, SystemCallError, TypeError, NoMethodError => e
        @unread << "Claude Code plugin skills not read: #{first_line(e.message)}"
        found
      end
    end

    # A plugin record that cannot be read is named; the other plugins are still checked.
    def add_plugin(found, name, installs)
      user = user_install(installs)
      folder = File.join(install_path(user), 'skills') if user
      return unless folder && File.directory?(folder)

      revision = user['gitCommitSha'] || user['version']
      skills(folder).each { |path| found << Skill.new(File.basename(path), path, "#{name} plugin", revision) }
    rescue KeyError, TypeError, NoMethodError, ArgumentError => e
      @unread << "#{name} plugin skills not read: #{first_line(e.message)}"
    end

    def user_install(installs)
      raise TypeError, 'record is not a list of objects' unless installs.is_a?(Array) && installs.all?(Hash)

      installs.find { |install| install['scope'] == 'user' }
    end

    # A relative path would resolve against wherever the scan runs, not the plugin.
    def install_path(user)
      path = user.fetch('installPath')
      raise ArgumentError, "installPath #{path} is not absolute" unless File.absolute_path?(path)

      path
    end

    def plugin(key) = key.to_s.split('@').first

    # Claude Code loads a user-scope plugin only while settings.json marks it enabled.
    def enabled_plugins
      enabled = object(object(json(SETTINGS), SETTINGS).fetch('enabledPlugins', {}), 'enabledPlugins')
      object(object(json(PLUGINS), PLUGINS).fetch('plugins', {}), 'plugins').select { |key, _| enabled[key] == true }
    end

    # These files are Claude Code's own; a changed shape degrades the scan instead of finding no plugins.
    def object(value, label) = value.is_a?(Hash) ? value : raise(TypeError, "#{label} is not a JSON object")

    # Only a missing file means no plugins; a file this account cannot reach is reported.
    def json(relative)
      JSON.parse(File.read(File.join(@home, relative)))
    rescue Errno::ENOENT
      {}
    end
  end
end
