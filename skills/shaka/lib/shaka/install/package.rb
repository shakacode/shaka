# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'

module Shaka
  module Install
    # Stages a complete copy, validates it, and retains previous copies for rollback.
    class Package
      METADATA = '.shaka-install.json'
      ALLOWED = %w[shaka rct mct-claude rct-claude].freeze

      def initialize(root, source, names, tree)
        @root = root
        @source = source
        @names = names
        @tree = tree
      end

      def prepare(source_root)
        hash = @tree.hash(source_root)
        identity = @source.identity(hash)
        id = identity_for(@source.version, identity)
        target = File.join(@root, id)
        return verify(target) if File.directory?(target)

        stage(source_root, target, hash, identity)
      end

      def existing(id)
        pattern = /\A[\w.]+-[0-9a-f]{64}-[0-9a-f]{64}\z/
        raise ArgumentError, 'Invalid package identity' unless id.match?(pattern)

        path = verify(File.join(@root, id))
        metadata = JSON.parse(File.read(File.join(path, METADATA)))
        raise ArgumentError, 'Rollback flags must match the package skills' unless metadata.fetch('skills') == @names

        path
      end

      def verify(path, content: true)
        metadata = JSON.parse(File.read(File.join(path, METADATA)))
        validate_metadata(path, metadata, content: content)
        path
      rescue Errno::ENOENT, JSON::ParserError, KeyError, TypeError
        raise ArgumentError, "Managed package is missing or invalid: #{path}"
      end

      private

      def identity_for(version, source)
        "#{version}-#{source.fetch('content_sha256')}-#{Digest::SHA256.hexdigest(JSON.generate(source))}"
      end

      def stage(source_root, target, hash, identity)
        FileUtils.mkdir_p(@root)
        staging = Dir.mktmpdir('.staging-', @root)
        begin
          build(staging, source_root, target, hash, identity)
        ensure
          FileUtils.rm_rf(staging)
        end
        target
      end

      def build(staging, source_root, target, hash, identity)
        @tree.copy(source_root, staging)
        raise ArgumentError, 'Source changed during installation' unless @tree.hash(staging) == hash
        raise ArgumentError, 'Source identity changed during installation' unless @source.identity(hash) == identity

        metadata = { 'schema_version' => 1, 'package_id' => File.basename(target),
                     'version' => @source.version, 'skills' => @names, 'source' => identity }
        File.write(File.join(staging, METADATA), "#{JSON.pretty_generate(metadata)}\n")
        @tree.reject_checkout_references(staging, source_root)
        File.rename(staging, target)
      end

      def validate_metadata(path, metadata, content:)
        names = metadata.fetch('skills')
        raise ArgumentError, 'Managed package skills are invalid' unless names.is_a?(Array) && (names - ALLOWED).empty?

        source = metadata.fetch('source')
        validate_identity(path, metadata, source)
        return unless content
        return if @tree.hash(path, names) == source.fetch('content_sha256')

        raise ArgumentError, 'Managed package content differs'
      end

      def validate_identity(path, metadata, source)
        expected = identity_for(metadata.fetch('version'), source)
        return if metadata['package_id'] == expected && File.basename(path) == expected

        raise ArgumentError, 'Managed package identity differs'
      end
    end
  end
end
