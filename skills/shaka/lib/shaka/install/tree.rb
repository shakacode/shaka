# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'open3'

module Shaka
  module Install
    # Enumerates and hashes only regular package files and directories.
    class Tree
      DOT_ENTRIES = ['.', '..'].freeze

      def initialize(names)
        @names = names
      end

      def entries(root, name)
        skill = File.join(root, 'skills', name)
        raise ArgumentError, "Missing skill: #{skill}" unless File.directory?(skill) && !File.symlink?(skill)

        paths = Dir.glob('**/*', File::FNM_DOTMATCH, base: skill)
                   .reject { |path| DOT_ENTRIES.include?(File.basename(path)) }
                   .sort.map { |path| File.join(skill, path) }
        ignored = ignored_files(root, paths)
        paths.reject { |path| ignored.include?(path) }
      end

      def hash(root, names = @names)
        digest = Digest::SHA256.new
        names.each do |name|
          digest.update(name).update("\0")
          entries(root, name).each { |path| add(digest, path, root) }
        end
        digest.hexdigest
      end

      def copy(source, target)
        @names.each do |name|
          destination = File.join(target, 'skills', name)
          FileUtils.mkdir_p(destination)
          directories = []
          entries(source, name).each do |path|
            copy_entry(path, source, target, directories)
          end
          directories.reverse_each { |path, mode| File.chmod(mode, path) }
        end
      end

      def reject_checkout_references(root, source)
        prefix = "#{source}/"
        @names.each do |name|
          entries(root, name).select { |path| File.file?(path) }.each do |path|
            raise ArgumentError, "Checkout reference in package: #{path}" if File.binread(path).include?(prefix)
          end
        end
      end

      private

      def ignored_files(root, paths)
        return [] unless git_source?(root)

        files = paths.select { |path| File.file?(path) || File.symlink?(path) }
        return [] if files.empty?

        output = git_ignored(root, files)
        output.split("\0").map { |path| File.join(root, path) }
      rescue Errno::ENOENT
        []
      end

      def git_source?(root)
        top, status = Open3.capture2('git', '-C', root, 'rev-parse', '--show-toplevel', err: File::NULL)
        status.success? && top.strip == root
      end

      def git_ignored(root, files)
        relative = files.map { |path| path.delete_prefix("#{root}/") }
        output, = Open3.capture2('git', '-C', root, 'check-ignore', '-z', '--stdin',
                                 stdin_data: "#{relative.join("\0")}\0", err: File::NULL)
        output
      end

      def copy_entry(path, source, target, directories)
        destination = File.join(target, path.delete_prefix("#{source}/"))
        validate_entry(path)
        if File.directory?(path)
          FileUtils.mkdir_p(destination)
          directories << [destination, File.stat(path).mode & 0o777]
        else
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(path, destination, preserve: true)
        end
      end

      def add(digest, path, root)
        validate_entry(path)
        digest.update(path.delete_prefix("#{root}/")).update("\0")
        digest.update((File.stat(path).mode & 0o777).to_s).update("\0")
        digest.update(File.file?(path) ? File.binread(path) : 'directory').update("\0")
      end

      def validate_entry(path)
        raise ArgumentError, "Symlink in skill package: #{path}" if File.symlink?(path)
        raise ArgumentError, "Unsupported package entry: #{path}" unless File.file?(path) || File.directory?(path)
      end
    end
  end
end
