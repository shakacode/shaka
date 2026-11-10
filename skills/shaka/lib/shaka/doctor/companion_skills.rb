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
      SHOWN = 5
      CLAUDE = '.claude'
      PLUGINS = File.join(CLAUDE, 'plugins', 'installed_plugins.json')
      SETTINGS = File.join(CLAUDE, 'settings.json')

      def initialize(home:)
        @home = home
      end

      def call
        return check(NAME, 'degraded', 'not checked: no home directory') unless @home

        folders = Install::Locations::HOSTS.values.map { |relative| File.join(@home, relative) }
        folders.select! { |folder| File.directory?(folder) }
        broken = folders.flat_map { |folder| broken_links(folder) }
        duplicates, skipped = claude_duplicates
        report(folders.length, broken, duplicates, skipped)
      rescue SystemCallError => e
        check(NAME, 'degraded', "not checked: #{first_line(e.message)}")
      end

      private

      def entries(folder)
        Dir.children(folder).reject { |name| name.start_with?('.') }.sort.map { |name| File.join(folder, name) }
      end

      def broken_links(folder) = entries(folder).select { |path| File.symlink?(path) && !File.exist?(path) }

      # Returns [{ name => [where it loads from, ...] }, reason plugin skills were not read or nil].
      def claude_duplicates
        sources = Hash.new { |hash, key| hash[key] = [] }
        folder = File.join(@home, Install::Locations::HOSTS.fetch('claude'))
        entries(folder).each { |path| sources[File.basename(path)] << shown(folder) } if File.directory?(folder)
        skipped = add_plugin_skills(sources)
        [sources.select { |_name, where| where.length > 1 }, skipped]
      end

      def add_plugin_skills(sources)
        enabled_plugins.each do |plugin, install_path|
          skills = File.join(install_path, 'skills')
          next unless File.directory?(skills)

          entries(skills).each { |path| sources[File.basename(path)] << "#{plugin} plugin" if File.directory?(path) }
        end
        nil
      rescue JSON::ParserError, KeyError, TypeError, NoMethodError => e
        "Claude Code plugin skills not read: #{first_line(e.message)}"
      end

      # Claude Code loads a user-scope plugin only while settings.json marks it enabled.
      def enabled_plugins
        enabled = json(SETTINGS).fetch('enabledPlugins', {})
        json(PLUGINS).fetch('plugins', {}).filter_map do |key, installs|
          user = installs.find { |install| install['scope'] == 'user' }
          [key.split('@').first, user.fetch('installPath')] if user && enabled[key] == true
        end
      end

      def json(relative)
        path = File.join(@home, relative)
        File.file?(path) ? JSON.parse(File.read(path)) : {}
      end

      def report(count, broken, duplicates, skipped)
        problems = [duplicate_text(duplicates), broken_text(broken), skipped].compact
        if problems.empty?
          return check(NAME, 'healthy', "no duplicate names or broken links in #{count} skill folder(s)")
        end

        check(NAME, 'degraded', problems.join('; '), guidance: guidance(duplicates, broken, skipped))
      end

      def duplicate_text(duplicates)
        return if duplicates.empty?

        items = duplicates.sort.map { |name, where| "#{name} (#{where.join(', ')})" }
        "Claude Code loads #{duplicates.length} skill name(s) twice: #{listed(items)}"
      end

      def broken_text(broken)
        return if broken.empty?

        "#{broken.length} skill link(s) point nowhere: #{listed(broken.map { |path| shown(path) })}"
      end

      def listed(items)
        rest = items.length - SHOWN
        [*items.first(SHOWN), ("and #{rest} more" if rest.positive?)].compact.join(', ')
      end

      def guidance(duplicates, broken, skipped)
        steps = []
        steps << 'Keep one copy of each duplicated skill, or disable the plugin that repeats it.' if duplicates.any?
        steps << 'Repoint or remove each broken link.' if broken.any?
        steps << "Check that ~/#{PLUGINS} and ~/#{SETTINGS} hold valid JSON." if skipped
        "#{steps.join(' ')} Doctor changes nothing."
      end

      def shown(path) = path.start_with?("#{@home}/") ? "~#{path.delete_prefix(@home)}" : path
    end
  end
end
