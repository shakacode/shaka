# frozen_string_literal: true

require 'fileutils'

module Shaka
  module Install
    # Switches only Shaka owned host links after the complete package is ready.
    class Links
      def initialize(skills_dir, managed, source, names, package)
        @skills_dir = skills_dir
        @managed = managed
        @source = source
        @names = names
        @package = package
      end

      def switch_all(target)
        preflight(target)
        previous = @names.to_h { |name| [name, old_target(name)] }
        switch_links(target, previous)
      end

      private

      def switch_links(target, previous)
        changed = []
        begin
          @names.each do |name|
            switch_one(name, target)
            changed << name
          end
        rescue SystemCallError
          changed.reverse_each { |name| restore(name, previous[name]) }
          raise
        end
      end

      def destination(name) = File.join(@skills_dir, name)

      def old_target(name)
        File.readlink(destination(name)) if File.symlink?(destination(name))
      end

      def preflight(target)
        @names.each do |name|
          raise ArgumentError, "Package lacks #{name}" unless File.directory?(File.join(target, 'skills', name))
          next unless File.exist?(destination(name)) || File.symlink?(destination(name))
          next if owned?(name)

          raise ArgumentError, "Refusing existing destination: #{destination(name)}"
        end
      end

      def owned?(name)
        target = old_target(name)
        return false unless target
        return true if target == File.join(@source, 'skills', name)

        package = File.dirname(target, 2)
        return false unless target == File.join(package, 'skills', name)
        return false unless package.start_with?("#{@managed}/")

        @package.verify(package)
        true
      end

      def switch_one(name, package)
        target = File.join(package, 'skills', name)
        return puts("Already installed: #{destination(name)}") if old_target(name) == target

        FileUtils.mkdir_p(@skills_dir)
        temporary = File.join(@skills_dir, ".#{name}.shaka-#{Process.pid}")
        File.symlink(target, temporary)
        File.rename(temporary, destination(name))
        puts "Installed: #{destination(name)} -> #{target}"
      ensure
        File.unlink(temporary) if temporary && File.symlink?(temporary)
      end

      def restore(name, previous)
        File.unlink(destination(name))
        File.symlink(previous, destination(name)) if previous
      end
    end
  end
end
