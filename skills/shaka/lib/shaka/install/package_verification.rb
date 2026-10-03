# frozen_string_literal: true

require_relative 'directory_safety'

module Shaka
  module Install
    # Checks the outer package container before trusting its recorded identity.
    module PackageVerification
      include DirectorySafety

      private

      def ensure_managed_root = ensure_safe_directory(@root, 'Managed directory')

      def verify_managed_root = verify_safe_directory(@root, 'Managed directory')

      def verified_metadata(path)
        raise ArgumentError, "Managed package root is invalid: #{path}" unless valid_container?(path)

        skills = File.join(path, 'skills')
        raise ArgumentError, "Managed package skills directory is invalid: #{skills}" unless valid_container?(skills)

        metadata_path = File.join(path, Package::METADATA)
        reject_non_file_metadata(metadata_path)

        metadata = JSON.parse(File.read(metadata_path))
        validate_metadata(path, metadata)
        metadata
      rescue Errno::ENOENT, JSON::ParserError, KeyError, TypeError
        raise ArgumentError, "Managed package is missing or invalid: #{path}"
      end

      def valid_container?(path)
        !File.symlink?(path) && File.directory?(path) && (File.stat(path).mode & 0o777) == 0o755
      end

      def validate_metadata(path, metadata)
        raise ArgumentError, 'Managed package metadata must be an object' unless metadata.is_a?(Hash)

        names = metadata.fetch('skills')
        raise ArgumentError, 'Managed package skills are invalid' unless Package.valid_skills?(names)

        source = metadata.fetch('source')
        raise ArgumentError, 'Managed package source must be an object' unless source.is_a?(Hash)

        validate_identity(path, metadata, source)
        return if @tree.hash(path, names) == source.fetch('package_content_sha256', source.fetch('content_sha256'))

        raise ArgumentError, 'Managed package content differs'
      end

      def validate_identity(path, metadata, source)
        expected = Package.identity_for(metadata.fetch('version'), source)
        return if metadata['package_id'] == expected && File.basename(path) == expected

        raise ArgumentError, 'Managed package identity differs'
      end

      def reject_non_file_metadata(path)
        return if File.lstat(path).file?

        raise ArgumentError, "Managed package metadata is invalid: #{path}"
      end
    end
  end
end
