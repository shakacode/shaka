# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require_relative '../error'

module Shaka
  class Seam
    # Starts a worktree's private settings from another worktree's recovery copy.
    module PrivateSeed
      SEED_TEMPORARY = '.shaka-seed-'
      SEED_TEMPORARY_NAME = /#{Regexp.escape(SEED_TEMPORARY)}\h{12}\z/

      private

      def seeding? = @options.key?(:from)

      def seeded_files
        extra = @options.keys - %i[root ref from]
        raise Error, "--from copies existing settings; omit #{extra.join(', ')}" if extra.any?

        copy = PrivateRecovery.new(root: @root, assign_identity: false).seed_files(@options[:from])
        copy.to_h { |relative, content| [File.join(private_root, relative), content] }
      end

      # Seeded copies may hold files setup never generates, such as a custom review prompt.
      def preflight_files(files)
        return super unless seeding?

        files.each { |path, content| seeded_file_present?(path, content, seeded_mode(path)) }
      end

      def write_files(files)
        return super unless seeding?

        preflight_directories
        FileUtils.mkdir_p(private_root)
        files.each { |path, content| write_seeded_file(path, content) }
      end

      def write_seeded_file(path, content)
        mode = seeded_mode(path)
        return if seeded_file_present?(path, content, mode)

        assert_inside_private_root!(existing_parent(File.dirname(path)))
        FileUtils.mkdir_p(File.dirname(path))
        assert_inside_private_root!(File.dirname(path))
        install_seeded_file(path, content, mode)
      end

      # A partial write stays in a temporary file, so the rerun never meets it at the destination.
      def install_seeded_file(path, content, mode)
        temporary = "#{path}#{SEED_TEMPORARY}#{SecureRandom.hex(6)}"
        File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.write(content)
          file.chmod(mode)
        end
        File.rename(temporary, path)
      ensure
        FileUtils.rm_f(temporary) if temporary
      end

      # A killed seed can leave its temporary files; the rerun removes them before checking the tree.
      # Runs after setup refuses symlinked destination directories, and only inside the real private tree.
      def remove_seed_temporaries
        preflight_directories
        return unless File.directory?(private_root)

        Dir.glob("**/*#{SEED_TEMPORARY}*", File::FNM_DOTMATCH, base: private_root).each do |relative|
          path = File.join(private_root, relative)
          File.unlink(path) if seed_temporary?(path)
        end
      end

      def seed_temporary?(path)
        File.basename(path).match?(SEED_TEMPORARY_NAME) && File.file?(path) && !File.symlink?(path) &&
          "#{File.realpath(File.dirname(path))}/".start_with?("#{File.realpath(private_root)}/")
      end

      # Matches the recovery copy's mode rule so an interrupted seed resumes like setup.
      def seeded_mode(path) = path.start_with?(File.join(private_root, 'bin/')) ? 0o755 : 0o644

      def private_root = File.join(@root, PrivateRecovery::PRIVATE_DIRECTORY)

      def assert_inside_private_root!(directory)
        return if "#{File.realpath(directory)}/".start_with?("#{File.realpath(private_root)}/")

        raise Error, "Refusing unsafe directory: #{directory.delete_prefix("#{@root}/")}"
      end

      def seeded_file_present?(path, content, mode)
        return false unless File.exist?(path) || File.symlink?(path)
        return true if File.file?(path) && !File.symlink?(path) && (File.stat(path).mode & 0o7777) == mode &&
                       File.binread(path) == content

        raise Error, "Refusing existing destination: #{path.delete_prefix("#{@root}/")}"
      end
    end
  end
end
