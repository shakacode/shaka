# frozen_string_literal: true

require_relative 'check'
require_relative 'companion_skills_text'
require_relative '../installed_skills'

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

      def initialize(home:)
        @home = home
        @scan = InstalledSkills.new(home:) if home
        @unread = @scan ? @scan.unread : []
      end

      def call
        return check(NAME, 'degraded', 'not checked: no home directory') unless @home

        paths = @scan.host_paths.values
        folders = paths.select { |folder| File.directory?(folder) }
        report(folders.length, broken_entries(paths, folders), duplicate_names)
      end

      private

      # A skills folder can itself be a link that points nowhere.
      def broken_entries(paths, folders)
        paths.select { |path| File.symlink?(path) && broken?(path) } + folders.flat_map { |f| broken_links(f) }
      end

      # A skill folder can hold a SKILL.md link that points nowhere, which drops the skill just the same.
      def broken_links(folder)
        @scan.entries(folder).flat_map do |path|
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

      # { name => [where Claude Code loads it from, ...] } for names it loads more than once.
      def duplicate_names
        sources = Hash.new { |hash, key| hash[key] = [] }
        @scan.claude_skills.each do |skill|
          sources[skill.name] << (skill.origin == 'claude' ? shown(File.dirname(skill.path)) : skill.origin)
        end
        sources.select { |_name, where| where.length > 1 }
      end

      def report(count, broken, duplicates)
        problems = [duplicate_text(duplicates), broken_text(broken), *@unread.uniq].compact
        if problems.empty?
          return check(NAME, 'healthy', "no duplicate names or broken links in #{count} skill folder(s)")
        end

        check(NAME, 'degraded', problems.join('; '), guidance: guidance(duplicates, broken))
      end

      def shown(path) = @scan.shown(path)
    end
  end
end
