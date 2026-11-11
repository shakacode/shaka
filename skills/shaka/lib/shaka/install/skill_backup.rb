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
        if home == skills || home.start_with?("#{skills}/")
          raise ArgumentError, 'No writable backup location outside the skills directory'
        end

        Dir.mktmpdir(prefix, home)
      end

      def relocate(source, backup)
        target = File.readlink(source) if File.symlink?(source)
        return FileUtils.mv(source, backup) unless target && Pathname.new(target).relative?

        absolute_link = "#{backup}.absolute"
        File.symlink(File.join(File.dirname(source), target), absolute_link)
        FileUtils.mv(source, backup)
        File.rename(absolute_link, backup) if same_link?(backup, target)
      ensure
        File.unlink(absolute_link) if absolute_link && File.symlink?(absolute_link)
      end

      def same_link?(path, target)
        File.symlink?(path) && File.readlink(path) == target
      end
    end
  end
end
