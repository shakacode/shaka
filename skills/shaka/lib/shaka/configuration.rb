# frozen_string_literal: true

require_relative 'configuration/paths'
require_relative 'configuration/layout'
require_relative 'repository_config'
require_relative 'trusted_config_source'
require_relative 'configuration/sources'
require_relative 'configuration/private_source'
require_relative 'configuration/generated_files'

module Shaka
  # Supported access to repository configuration. Worktree and trusted-commit reads
  # are deliberately separate; callers cannot turn a missing trusted file into a
  # checkout fallback. Explicit operation settings resolution also accepts a complete
  # private source without granting policy. RepositoryConfig and TrustedConfigSource remain focused internals.
  module Configuration
    extend Sources
    extend GeneratedFiles

    module_function

    def worktree(root:) = RepositoryConfig.load(root:)

    # ref is the caller-verified default-branch commit, not a candidate checkout ref.
    def private_source(root:, ref:) = PrivateSource.new(root:, ref:).resolve

    def trusted(root:, ref:, candidate_commands: true)
      TrustedConfigSource.load(root:, ref:, candidate_commands:)
    end

    # Operation settings can be private; this selection grants no trusted policy or merge authority.
    def resolve_source(root:, ref:, candidate_commands: true)
      sha = resolve_commit(root:, ref:, label: 'settings ref')
      source = private_source(root:, ref: sha)
      if source.status == 'complete'
        [source.candidate_config, { private_source: source }, 'private/local']
      else
        [trusted(root:, ref: sha, candidate_commands:), { trusted_ref: sha }, 'trusted/team']
      end
    end

    def opening_prompt(root:, config:)
      return TrustedConfigSource.new(root:).opening_prompt(config) if config.sha

      path = File.expand_path(config.opening_check.fetch('prompt_file'), root)
      text = nil
      error = ReviewPrompt.file_error(File.size(path)) { text = File.binread(path) }
      raise Error, "opening_check.prompt_file #{error}" if error

      text
    end

    def path(root, name)
      Paths.at(root, Paths::REPOSITORY_NAMES.fetch(name))
    end

    def command_path(root, name)
      Paths.at(root, Paths::COMMANDS.fetch(name.to_s))
    end

    def command_file?(root, name)
      File.file?(command_path(root, name))
    end

    def contract_entry?(root)
      !Layout.worktree(root:, allow_missing: true).nil?
    end

    def contract_matches?(root, source)
      target = path(root, :CONTRACT)
      File.file?(target) && !File.symlink?(target) && File.read(target) == source
    end

    def contract_changed?(root, source)
      target = path(root, :CONTRACT)
      File.file?(target) && File.read(target) != source
    end
  end
end
