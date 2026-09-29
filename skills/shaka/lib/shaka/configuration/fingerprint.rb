# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative '../repository_config'
require_relative 'fingerprint/canonical'
require_relative 'fingerprint/files'

module Shaka
  module Configuration
    # Internal, read-only identity of resolved settings and their inputs.
    # Component hashes are local comparison data, never public PR metadata.
    class Fingerprint
      VERSION = 1
      Result = Data.define(:version, :digest, :components, :effective_settings) do
        def to_h = { 'version' => version, 'digest' => digest, 'components' => components }
      end

      def self.build(root:, effective_settings:, repository:, installation:, **source)
        new(root:, effective_settings:, repository:, installation:, source:).build
      end

      def initialize(root:, effective_settings:, repository:, installation:, source:)
        @root = File.realpath(root)
        @settings = FingerprintCanonical.normalize(effective_settings)
        @repository = repository
        @installation = FingerprintCanonical.normalize(installation)
        @private_source = source[:private_source]
        @trusted_ref = source[:trusted_ref]
        @files = FingerprintFiles.new(@root)
      end

      def build
        validate_inputs!
        components = { 'effective_settings' => digest('effective-settings', @settings),
                       'source' => digest('source', source_identity),
                       'installation' => digest('installation', @installation),
                       'files' => file_hashes }
        Result.new(version: VERSION, digest: digest('fingerprint', components),
                   components: FingerprintCanonical.freeze_tree(components),
                   effective_settings: FingerprintCanonical.freeze_tree(@settings))
      end

      private

      def digest(label, value) = FingerprintCanonical.digest(label, value)

      def validate_inputs!
        validate_repository!
        raise Error, 'Effective settings must be a mapping' unless @settings.is_a?(Hash)

        validate_installation!
        raise Error, 'Select exactly one settings source' if @private_source.nil? == @trusted_ref.nil?

        validate_private_source! if @private_source
      end

      def validate_repository!
        return if @repository.is_a?(String) && @repository.match?(%r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z})

        raise Error, 'Repository identity must be owner/name'
      end

      def validate_installation!
        return if @installation.is_a?(Hash) && @installation['schema_version'] == 1 &&
                  @installation['version'].is_a?(String) && @installation['source'].is_a?(Hash)

        raise Error, 'Installation identity must be doctor --installation-json data'
      end

      def validate_private_source!
        raise Error, 'Private source preflight is not complete' unless @private_source.status == 'complete'
        raise Error, 'Private source belongs to another worktree' unless File.realpath(@private_source.root) == @root
      end

      def source_identity
        path = config_path
        common = { 'repository' => @repository, 'layout' => path,
                   'trusted_default_commit' => @private_source ? @private_source.ref : @trusted_ref }
        return common.merge('kind' => @private_source.mode, 'configuration_blob' => nil) if @private_source

        raise Error, 'Trusted source ref must be a full commit SHA' unless full_sha?(@trusted_ref)

        common.merge('kind' => 'trusted/team', 'configuration_blob' => config_blob(path))
      end

      def config_path
        @files.safe_path(@settings.fetch('paths').fetch('policy_configuration'))
      rescue KeyError
        raise Error, 'Effective settings lack policy configuration path'
      end

      def config_blob(path)
        out, err, status = Open3.capture3('git', '-C', @root, 'rev-parse', '--verify', "#{@trusted_ref}:#{path}")
        raise Error, "Cannot identify trusted configuration blob: #{err.strip}" unless status.success?

        blob = out.strip
        raise Error, 'Trusted configuration blob is invalid' unless full_sha?(blob)

        blob
      end

      def full_sha?(value) = value.is_a?(String) && value.match?(/\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/)

      def file_hashes
        paths = private_paths || @settings.fetch('commands').values
        paths += RepositoryConfig.prompt_files(review: @settings.fetch('review'),
                                               opening: @settings.fetch('opening_check')).map(&:last)
        @files.hashes(paths)
      end

      def private_paths
        return unless @private_source

        @private_source.inventory.map { |entry| entry.fetch(:path) } - [config_path]
      end
    end
  end
end
