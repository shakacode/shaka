# frozen_string_literal: true

require 'digest'
require 'pathname'
require_relative '../../error'
require_relative 'canonical'

module Shaka
  module Configuration
    # Reads repository-relative file inputs without following escapes.
    class FingerprintFiles
      def initialize(root)
        @root = root
      end

      def hashes(paths)
        paths.map { |path| safe_path(path) }.uniq.sort.to_h do |path|
          [path, FingerprintCanonical.digest('file', identity(path))]
        end
      end

      def safe_path(path)
        raise Error, 'Fingerprint path must be repository-relative' unless path.is_a?(String) && path.valid_encoding?
        raise Error, "Unsafe fingerprint path #{path}" if unsafe_path?(path)

        path
      end

      private

      def unsafe_path?(path)
        path.empty? || path.start_with?('/') ||
          path.split('/').any? { |part| part.empty? || %w[. ..].include?(part) }
      end

      def identity(path)
        full = File.join(@root, path)
        parent = File.realpath(File.dirname(full))
        raise Error, "#{path} traverses outside repository" unless parent == @root || parent.start_with?("#{@root}/")

        stat = File.lstat(full)
        return { 'type' => 'directory', 'mode' => stat.mode & 0o777 } if stat.directory?
        return symlink_identity(path, full) if stat.symlink?

        regular_identity(path, full, stat)
      rescue SystemCallError => e
        raise Error, "Cannot fingerprint #{path}: #{e.class}"
      end

      def regular_identity(path, full, stat)
        raise Error, "#{path} must be a regular file" unless stat.file?

        { 'type' => 'regular', 'mode' => stat.mode & 0o777,
          'bytes_sha256' => Digest::SHA256.file(full).hexdigest }
      end

      def symlink_identity(path, full)
        resolved = File.realpath(full)
        raise Error, "Symlink #{path} escapes repository" unless resolved.start_with?("#{@root}/")
        raise Error, "Symlink #{path} must target a regular file" unless File.file?(resolved)

        { 'type' => 'symlink', 'target' => File.readlink(full),
          'resolved_path' => Pathname.new(resolved).relative_path_from(Pathname.new(@root)).to_s,
          'resolved_mode' => File.stat(resolved).mode & 0o777,
          'resolved_bytes_sha256' => Digest::SHA256.file(resolved).hexdigest }
      end
    end
  end
end
