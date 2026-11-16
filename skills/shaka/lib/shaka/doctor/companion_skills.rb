# frozen_string_literal: true

require 'json'
require_relative 'check'
require_relative 'companion_skills_text'
require_relative '../install/locations'

module Shaka
  class Doctor
    # Reports skills that one coding agent loads twice and skill links that point nowhere.
    # Each agent reads only its own folder, so the same name in two agents' folders is normal;
    # Claude Code also loads enabled plugins' skills under a namespace, beside its folder's
    # copies. Report-only: nothing here changes a folder.
    class CompanionSkills
      include Check
      include CompanionSkillsText

      NAME = 'Companion skills'
      CLAUDE = Install::Locations::HOSTS.fetch('claude')
      PLUGINS = File.join('.claude', 'plugins', 'installed_plugins.json')
      SETTINGS = File.join('.claude', 'settings.json')

      def initialize(home:)
        @home = home
        @unread = []
      end

      def call
        return check(NAME, 'degraded', 'not checked: no home directory') unless @home

        paths = Install::Locations::HOSTS.values.map { |relative| File.join(@home, relative) }
        folders = paths.select { |folder| File.directory?(folder) }
        report(folders.length, broken_entries(paths, folders), duplicate_names)
      end

      private

      # An unreadable folder is named in the report; the other folders are still checked.
      def entries(folder)
        Dir.children(folder).reject { |name| name.start_with?('.') }.sort.map { |name| File.join(folder, name) }
      rescue SystemCallError => e
        @unread << "#{shown(folder)} not read: #{first_line(e.message)}"
        []
      end

      # A skills folder can itself be a link that points nowhere.
      def broken_entries(paths, folders)
        paths.select { |path| File.symlink?(path) && broken?(path) } + folders.flat_map { |f| broken_links(f) }
      end

      # A skill folder can hold a SKILL.md link that points nowhere, which drops the skill just the same.
      def broken_links(folder)
        entries(folder).flat_map do |path|
          [path, File.join(path, 'SKILL.md')].select { |link| File.symlink?(link) && broken?(link) }
        end
      end

      # A target that cannot be reached is unread, not broken, so a working link is never called broken.
      def broken?(path)
        File.stat(path)
        false
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ELOOP
        true
      rescue SystemCallError => e
        @unread << "#{shown(path)} not read: #{first_line(e.message)}"
        false
      end

      # Only a folder holding SKILL.md loads as a skill, so a broken link or stray file is no copy.
      def skills(folder) = entries(folder).select { |path| skill?(path) }

      # A skill this account cannot read is named, so it never silently drops out of the comparison.
      def skill?(path)
        File.stat(File.join(path, 'SKILL.md')).file?
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ELOOP
        false
      rescue SystemCallError => e
        @unread << "#{shown(path)} not read: #{first_line(e.message)}"
        false
      end

      # { name => [where Claude Code loads it from, ...] } for names it loads more than once.
      def duplicate_names
        sources = Hash.new { |hash, key| hash[key] = [] }
        folder = File.join(@home, CLAUDE)
        skills(folder).each { |path| sources[File.basename(path)] << shown(folder) } if File.directory?(folder)
        add_plugin_skills(sources)
        sources.select { |_name, where| where.length > 1 }
      end

      def add_plugin_skills(sources)
        enabled_plugins.each { |key, installs| add_plugin(sources, plugin(key), installs) }
      rescue JSON::ParserError, SystemCallError, TypeError, NoMethodError => e
        @unread << "Claude Code plugin skills not read: #{first_line(e.message)}"
      end

      # A plugin record that cannot be read is named; the other plugins are still checked.
      def add_plugin(sources, name, installs)
        user = user_install(installs)
        folder = File.join(install_path(user), 'skills') if user
        return unless folder && File.directory?(folder)

        skills(folder).each { |path| sources[File.basename(path)] << "#{name} plugin" }
      rescue KeyError, TypeError, NoMethodError, ArgumentError => e
        @unread << "#{name} plugin skills not read: #{first_line(e.message)}"
      end

      def user_install(installs)
        raise TypeError, 'record is not a list of objects' unless installs.is_a?(Array) && installs.all?(Hash)

        installs.find { |install| install['scope'] == 'user' }
      end

      # A relative path would resolve against wherever doctor runs, not the plugin.
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

      # These files are Claude Code's own; a changed shape degrades the check instead of finding no plugins.
      def object(value, label) = value.is_a?(Hash) ? value : raise(TypeError, "#{label} is not a JSON object")

      # Only a missing file means no plugins; a file this account cannot reach is reported.
      def json(relative)
        JSON.parse(File.read(File.join(@home, relative)))
      rescue Errno::ENOENT
        {}
      end

      def report(count, broken, duplicates)
        problems = [duplicate_text(duplicates), broken_text(broken), *@unread.uniq].compact
        if problems.empty?
          return check(NAME, 'healthy', "no duplicate names or broken links in #{count} skill folder(s)")
        end

        check(NAME, 'degraded', problems.join('; '), guidance: guidance(duplicates, broken))
      end

      def shown(path) = path.start_with?("#{@home}/") ? "~#{path.delete_prefix(@home)}" : path
    end
  end
end
