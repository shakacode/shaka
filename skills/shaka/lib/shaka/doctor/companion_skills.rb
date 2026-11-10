# frozen_string_literal: true

require 'json'
require_relative 'check'
require_relative '../install/locations'

module Shaka
  class Doctor
    # Reports skills that one coding agent loads twice and skill links that point nowhere.
    # Each agent reads only its own folder, so the same name in two agents' folders is normal;
    # Claude Code also loads enabled plugins' skills under a namespace, beside its folder's
    # copies. Report-only: nothing here changes a folder.
    class CompanionSkills
      include Check

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

        folders = Install::Locations::HOSTS.values.map { |relative| File.join(@home, relative) }
        folders.select! { |folder| File.directory?(folder) }
        broken = folders.flat_map { |folder| broken_links(folder) }
        report(folders.length, broken, duplicate_names)
      end

      private

      # An unreadable folder is named in the report; the other folders are still checked.
      def entries(folder)
        Dir.children(folder).reject { |name| name.start_with?('.') }.sort.map { |name| File.join(folder, name) }
      rescue SystemCallError => e
        @unread << "#{shown(folder)} not read: #{first_line(e.message)}"
        []
      end

      def broken_links(folder) = entries(folder).select { |path| File.symlink?(path) && broken?(path) }

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
      def skills(folder) = entries(folder).select { |path| File.file?(File.join(path, 'SKILL.md')) }

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
        user = installs.find { |install| install['scope'] == 'user' }
        folder = File.join(user.fetch('installPath'), 'skills') if user
        return unless folder && File.directory?(folder)

        skills(folder).each { |path| sources[File.basename(path)] << "#{name} plugin" }
      rescue KeyError, TypeError, NoMethodError, ArgumentError => e
        @unread << "#{name} plugin skills not read: #{first_line(e.message)}"
      end

      def plugin(key) = key.to_s.split('@').first

      # Claude Code loads a user-scope plugin only while settings.json marks it enabled.
      def enabled_plugins
        enabled = json(SETTINGS).fetch('enabledPlugins', {})
        json(PLUGINS).fetch('plugins', {}).select { |key, _installs| enabled[key] == true }
      end

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

      def duplicate_text(duplicates)
        return if duplicates.empty?

        items = duplicates.sort.map { |name, where| "#{name} (#{where.join(', ')})" }
        "Claude Code loads #{duplicates.length} skill name(s) twice: #{items.join(', ')}"
      end

      def broken_text(broken)
        return if broken.empty?

        "#{broken.length} skill link(s) point nowhere: #{broken.map { |path| shown(path) }.join(', ')}"
      end

      def guidance(duplicates, broken)
        steps = []
        steps << 'Keep one copy of each duplicated skill, or disable the plugin that repeats it.' if duplicates.any?
        steps << 'Repoint or remove each broken link.' if broken.any?
        steps << "Make each folder named as not read readable, and ~/#{PLUGINS} and ~/#{SETTINGS} valid JSON." \
          if @unread.any?
        "#{steps.join(' ')} Doctor changes nothing."
      end

      def shown(path) = path.start_with?("#{@home}/") ? "~#{path.delete_prefix(@home)}" : path
    end
  end
end
