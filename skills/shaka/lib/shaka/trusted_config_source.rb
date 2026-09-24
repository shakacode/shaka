# frozen_string_literal: true

require 'open3'
require_relative 'repository_config'
require_relative 'trusted_path_resolver'

module Shaka
  # Reads repository policy from an immutable commit resolved from a trusted ref.
  class TrustedConfigSource
    def self.load(root:, ref: nil, candidate_commands: true)
      return RepositoryConfig.load(root:) unless ref

      new(root:, candidate_commands:).load(ref)
    end

    # PR commands read policy only from a trusted ref; without one they keep GitHub's native gates
    # instead of falling back to the candidate file.
    def self.from_ref(root:, ref:)
      load(root:, ref:) if ref
    end

    def initialize(root:, candidate_commands: true)
      @root = root
      @candidate_commands = candidate_commands
    end

    def load(ref)
      sha = resolve(ref)
      source, error, status = Open3.capture3('git', '-C', @root, 'show', "#{sha}:#{RepositoryConfig::PATH}")
      raise Error, "Cannot read #{RepositoryConfig::PATH} at #{ref}: #{error.strip}" unless status.success?

      RepositoryConfig.load(root: @root, source:, available_commands: optional_commands(sha), sha:,
                            candidate_commands: @candidate_commands)
    end

    private

    def resolve(ref)
      arguments = ['git', '-C', @root, 'rev-parse', '--verify', '--end-of-options', "#{ref}^{commit}"]
      sha, error, status = Open3.capture3(*arguments)
      raise Error, "Invalid trusted ref #{ref}: #{error.strip}" unless status.success?

      sha.strip
    end

    def optional_commands(sha)
      validate_command_directory(sha)
      resolver = TrustedPathResolver.new(root: @root, sha:)
      validate_required_commands(resolver, sha)
      entries = command_entries(resolver)
      validate_legacy_command_entries(resolver, entries, sha)
      RepositoryConfig::CommandPaths::OPTIONAL.filter_map do |name, path|
        next unless entries.key?(path)

        validate_command_entry(entries.fetch(path), path, sha, resolver)
        name
      end
    end

    def validate_required_commands(resolver, sha)
      RepositoryConfig::CommandPaths::REQUIRED.each_value do |path|
        entry = resolver.entry(path)
        raise Error, "#{path} is missing at trusted ref #{sha}" unless entry

        validate_command_entry(entry, path, sha, resolver)
      end
    end

    def validate_command_directory(sha)
      type, error, status = Open3.capture3('git', '-C', @root, 'cat-file', '-t', "#{sha}:.agents/bin")
      return if status.success? && type.strip == 'tree'
      raise Error, ".agents/bin at #{sha} must be a real directory, not a symlink" if status.success?

      raise Error, "Cannot inspect .agents/bin at #{sha}: #{error.strip}"
    end

    def command_entries(resolver)
      RepositoryConfig::CommandPaths::OPTIONAL.values.to_h do |path|
        [path, resolver.entry(path)]
      end.compact
    end

    def validate_legacy_command_entries(resolver, entries, sha)
      RepositoryConfig::CommandPaths::LEGACY_OPTIONAL.each do |name, legacy_path|
        fixed_path = RepositoryConfig::CommandPaths::OPTIONAL.fetch(name)
        next unless resolver.entry(legacy_path) && !entries.key?(fixed_path)

        raise Error, "#{legacy_path} requires the standard entry point #{fixed_path} at trusted ref #{sha}"
      end
    end

    def validate_command_entry(entry, path, sha, resolver)
      mode, type = entry
      return if type == 'blob' && mode == '100755'
      return validate_symlink_target(path, sha, resolver) if type == 'blob' && mode == '120000'

      raise Error, "#{path} at #{sha} must be an executable file or symlink"
    end

    def validate_symlink_target(path, sha, resolver)
      resolved, entry = resolver.resolve(path)
      return if entry == %w[100755 blob]

      raise Error, "#{path} at #{sha} must target a tracked executable file: #{resolved}"
    end
  end
end
