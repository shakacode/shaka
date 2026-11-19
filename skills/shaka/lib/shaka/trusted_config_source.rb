# frozen_string_literal: true

require 'open3'
require_relative 'repository_config'
require_relative 'review_prompt'
require_relative 'trusted_path_resolver'
require_relative 'configuration/layout'
require_relative 'configuration/sources'
require_relative 'configuration/private_source'
require_relative 'configuration/settings_preview'

module Shaka
  # Reads repository policy from an immutable commit resolved from a trusted ref.
  class TrustedConfigSource
    include Configuration::Sources

    LAYOUT = Configuration::Layout::CURRENT

    def self.load(root:, ref: nil, candidate_commands: true)
      ref ? new(root:, candidate_commands:).load(ref) : RepositoryConfig.load(root:)
    end

    # An explicit task selection replaces repository settings. Private fallback settings
    # still grant no policy, and a candidate file cannot select itself.
    def self.from_ref(root:, ref:, private_trial: false)
      return unless ref

      require_relative 'configuration'
      config, _, kind = Configuration.resolve_source(root:, ref:)
      return config unless kind == 'private/local'

      load(root:, ref:) unless private_trial
    end

    def initialize(root:, candidate_commands: true)
      @root = root
      @candidate_commands = candidate_commands
    end

    def load(ref)
      sha = resolve(ref)
      # Refuses a contract that is a symlink or not a file.
      Configuration::Layout.commit(root: @root, sha:, allow_missing: true)
      source = read_at_commit(root: @root, sha:, display_ref: ref)
      config = RepositoryConfig.load(root: @root, source:, available_commands: optional_commands(sha), sha:,
                                     candidate_commands: @candidate_commands)
      validate_prompt_files(config, sha)
      config
    end

    def opening_prompt(config, ref: config.sha)
      key = RepositoryConfig::ReviewSchema::PROMPT_FILE
      path = config.opening_check[key]
      return unless path

      read_prompt(path, ref, "opening_check.#{key}")
    end

    def read_prompt(path, sha, label)
      resolved, entry = TrustedPathResolver.new(root: @root, sha:).resolve(path)
      is_blob = entry && entry.last == 'blob' && entry.first != TrustedPathResolver::SYMLINK.first
      raise Error, "#{label} does not name a file at #{sha}: #{path}" unless is_blob

      text = nil
      error = ReviewPrompt.file_error(git_output(sha, resolved, '-s').to_i) { text = git_output(sha, resolved, '-p') }
      raise Error, "#{label} #{path} at #{sha} #{error}" if error

      text.force_encoding(Encoding::UTF_8)
    end

    private

    # A prompt file the review runner would reject would stop every local review, including the one
    # for the PR that fixes it.
    def validate_prompt_files(config, sha)
      config.prompt_files.each { |label, path| read_prompt(path, sha, label) }
    end

    # `-s` prints the blob size and `-p` its contents.
    def git_output(sha, path, option)
      text, error, status = Open3.capture3('git', '-C', @root, 'cat-file', option, "#{sha}:#{path}", binmode: true)
      raise Error, "Cannot read #{path} at #{sha}: #{error.strip}" unless status.success?

      text
    end

    def resolve(ref) = resolve_commit(root: @root, ref:, label: 'trusted ref')

    def optional_commands(sha)
      validate_command_directory(sha)
      resolver = TrustedPathResolver.new(root: @root, sha:)
      validate_required_commands(resolver, sha)
      entries = command_entries(resolver)
      LAYOUT.optional.filter_map do |name, path|
        next unless entries.key?(path)

        validate_command_entry(entries.fetch(path), path, sha, resolver)
        name
      end
    end

    def validate_required_commands(resolver, sha)
      LAYOUT.required.each_value do |path|
        entry = resolver.entry(path)
        raise Error, "#{path} is missing at trusted ref #{sha}" unless entry

        validate_command_entry(entry, path, sha, resolver)
      end
    end

    def validate_command_directory(sha)
      directory = LAYOUT.command_directory
      type, error, status = Configuration::GitMemo.capture([:object_type, @root, sha, directory], sha) do
        Open3.capture3('git', '-C', @root, 'cat-file', '-t', "#{sha}:#{directory}")
      end
      return if status.success? && type.strip == 'tree'
      raise Error, "#{directory} at #{sha} must be a real directory, not a symlink" if status.success?

      raise Error, "Cannot inspect #{directory} at #{sha}: #{error.strip}"
    end

    def command_entries(resolver)
      LAYOUT.optional.values.to_h { |path| [path, resolver.entry(path)] }.compact
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
