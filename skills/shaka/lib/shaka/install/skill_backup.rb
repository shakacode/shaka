# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

module Shaka
  module Install
    # Moves a conflicting entry out of the host's discovery directory.
    module SkillBackup
      module_function

      def move(path)
        skills = File.realpath(File.dirname(path))
        name = File.basename(path)
        backup = File.join(backup_directory(skills), name)
        relocate(File.join(skills, name), backup)
        puts "Backed up to #{backup}"
      end

      def backup_directory(skills)
        parent = File.dirname(skills)
        raise ArgumentError, 'No backup location outside the skills directory' if parent == skills

        prefix = "#{File.basename(skills)}.before-shaka."
        Dir.mktmpdir(prefix, parent)
      rescue Errno::EACCES, Errno::EPERM, Errno::EROFS
        home = File.realpath(Dir.home)
        raise if home == skills || home.start_with?("#{skills}/")

        Dir.mktmpdir(prefix, home)
      end

      def relocate(source, backup)
        FileUtils.mv(source, backup)
        target = File.readlink(backup) if File.symlink?(backup)
        return unless target && Pathname.new(target).relative?

        absolute_link = "#{backup}.absolute"
        File.symlink(File.join(File.dirname(source), target), absolute_link)
        File.rename(absolute_link, backup)
      end
    end
  end
end
