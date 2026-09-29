# frozen_string_literal: true

module Shaka
  class Seam
    # Adds the one shared Git exclusion without removing existing user rules.
    class PrivateRecovery
      def exclude!
        path = File.join(@common_git_dir, 'info/exclude')
        FileUtils.mkdir_p(File.dirname(path))
        lock = "#{path}.shaka.lock"
        File.open(lock, File::RDWR | File::CREAT, 0o600) do |file|
          file.flock(File::LOCK_EX)
          update_exclude(path)
        end
      rescue SystemCallError => e
        raise Error, "Cannot write #{path}: #{e.message}"
      end

      private

      def update_exclude(path)
        raise Error, "Unsafe exclude path: #{path}" if File.symlink?(path)

        existing = File.file?(path) ? File.binread(path) : ''
        return if existing.lines.any? { |line| line.chomp == Configuration::Paths::PRIVATE_EXCLUDE_PATTERN }

        content = existing.dup
        content << "\n" unless content.empty? || content.end_with?("\n")
        content << "#{Configuration::Paths::PRIVATE_EXCLUDE_PATTERN}\n"
        write_exclude(path, content)
      end

      def write_exclude(path, content)
        temporary = "#{path}.shaka-#{SecureRandom.hex(6)}"
        File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(content) }
        File.chmod(File.stat(path).mode & 0o7777, temporary) if File.file?(path)
        File.rename(temporary, path)
      ensure
        File.delete(temporary) if defined?(temporary) && temporary && File.exist?(temporary)
      end
    end
  end
end
