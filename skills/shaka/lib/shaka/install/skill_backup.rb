# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

module Shaka
  module Install
    # Moves a conflicting entry out of the host's discovery directory.
    module SkillBackup
      module_function

      def run(path)
        move(path)
      rescue ArgumentError, SystemCallError => e
        abort "Could not back up #{path}: #{e.message}"
      end

      def move(path)
        skills = File.realpath(File.dirname(path))
        name = File.basename(path)
        directory = backup_directory(skills)
        backup = File.join(directory, name)
        relocate(File.join(skills, name), backup)
        puts "Backed up to #{backup}"
      rescue SystemCallError
        Dir.rmdir(directory) if directory && Dir.empty?(directory)
        raise
      end

      def backup_directory(skills)
        parent = File.dirname(skills)
        raise ArgumentError, 'No backup location outside the skills directory' if parent == skills

        Dir.mktmpdir('shaka.before-shaka.', parent)
      rescue Errno::EACCES, Errno::EPERM, Errno::EROFS
        home = File.realpath(Dir.home)
        if home == skills || home.start_with?("#{skills}/")
          raise ArgumentError, 'No writable backup location outside the skills directory'
        end

        Dir.mktmpdir('shaka.before-shaka.', home)
      end

      def relocate(source, backup)
        target = File.readlink(source) if File.symlink?(source)
        return FileUtils.mv(source, backup) unless target && Pathname.new(target).relative?

        absolute_link = "#{backup}.absolute"
        anchor_link(source, target, absolute_link)
        FileUtils.mv(source, backup)
        File.rename(absolute_link, backup) if same_link?(backup, target)
      ensure
        File.unlink(absolute_link) if absolute_link && File.symlink?(absolute_link)
      end

      def anchor_link(source, target, backup)
        File.symlink(File.join(File.dirname(source), target), backup)
      rescue Errno::ENAMETOOLONG
        File.symlink(File.realpath(source), backup)
      end

      def same_link?(path, target)
        File.symlink?(path) && File.readlink(path) == target
      end
    end
  end
end
