# frozen_string_literal: true

require 'digest'
require 'fileutils'

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

        Dir.glob('**/*', File::FNM_DOTMATCH, base: skill)
           .reject { |path| DOT_ENTRIES.include?(File.basename(path)) }
           .sort.map { |path| File.join(skill, path) }
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
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp_r(File.join(source, 'skills', name), destination, preserve: true)
        end
      end

      def reject_checkout_references(root, source)
        @names.each do |name|
          entries(root, name).select { |path| File.file?(path) }.each do |path|
            raise ArgumentError, "Checkout reference in package: #{path}" if File.binread(path).include?(source)
          end
        end
      end

      private

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
