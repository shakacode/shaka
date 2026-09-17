# frozen_string_literal: true

require 'fileutils'
require_relative '../error'

module Shaka
  class Seam
    # Refuses foreign destinations and writes generated seam files conservatively.
    module InitializerDestination
      private

      def preflight_directories
        ['.agents', '.agents/bin'].each do |relative|
          path = File.join(@root, relative)
          next unless File.exist?(path) || File.symlink?(path)

          raise Error, "Refusing unsafe directory: #{relative}" if File.symlink?(path) || !File.directory?(path)
        end
      end

      def preflight_files(files)
        files.each do |path, content|
          next unless File.exist?(path) || File.symlink?(path)
          next if matching_destination?(path, content)

          raise Error, "Refusing existing destination: #{path.delete_prefix("#{@root}/")}"
        end
      end

      def matching_destination?(path, content)
        matches = File.file?(path) && !File.symlink?(path) && File.read(path, encoding: 'UTF-8') == content
        matches &&= (File.stat(path).mode & 0o7777) == destination_mode(path)
        matches
      end

      def write_files(files)
        # Narrow accidental-change windows; same-target concurrent writers are unsupported.
        preflight_directories
        preflight_files(files)
        FileUtils.mkdir_p(File.join(@root, '.agents/bin'))
        preflight_directories
        files.each do |path, content|
          preflight_directories
          preflight_files(path => content)
          write_new_file(path, content) unless File.file?(path)
        end
      end

      def write_new_file(path, content)
        flags = File::WRONLY | File::CREAT | File::EXCL
        File.open(path, flags, 0o600) do |file|
          file.write(content)
          file.chmod(destination_mode(path))
        end
      end

      def destination_mode(path) = wrapper_path?(path) ? 0o755 : 0o644

      def wrapper_path?(path) = File.dirname(path) == File.join(@root, '.agents/bin')
    end
  end
end
