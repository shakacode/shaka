# frozen_string_literal: true

require 'open3'
require 'pathname'
require_relative '../error'
require_relative '../repository_config'
require_relative 'layout'
require_relative 'private_inventory'

module Shaka
  module Configuration
    # Local report; candidate_config is deliberately omitted from its printable form.
    PrivateSourceResult = Data.define(:root, :common_git_dir, :ref, :trusted_source, :status, :inventory,
                                      :blockers, :candidate_config) do
      def mode = 'private/local'
      def grants_policy? = false
      def grants_merge_authority? = false

      def to_h
        { 'mode' => mode, 'grants_policy' => grants_policy?, 'grants_merge_authority' => grants_merge_authority?,
          'root' => root,
          'common_git_dir' => common_git_dir, 'ref' => ref, 'trusted_source' => trusted_source,
          'status' => status, 'inventory' => inventory, 'blockers' => blockers }
      end

      def inspect = "#<#{self.class} mode=#{mode} status=#{status}>"
      alias_method :to_s, :inspect
      def pretty_print(printer) = printer.text(inspect)
    end

    # Read-only preflight of private candidate settings in one Git worktree.
    class PrivateSource
      def initialize(root:, ref:)
        @root = File.realpath(root)
        @ref = ref
        @blockers = []
      end

      def resolve
        verify_worktree!
        sha = resolved_ref
        trusted = Layout.commit(root: @root, sha:, allow_missing: true)
        indexed = git('ls-files', '--cached', '-z').split("\0")
        committed = committed_paths
        inventory = PrivateInventory.new(root: @root, committed:).scan
        @blockers.concat(inventory.blockers)
        inspect_conflicts(trusted, indexed, committed, inventory.entries)
        config = load_candidate(inventory, committed)
        result(sha, trusted, inventory, config)
      end

      private

      def committed_paths = git('ls-tree', '-r', '-z', '--name-only', 'HEAD').split("\0")

      def resolved_ref
        raise Error, 'Private source ref must be an immutable commit SHA' unless
          @ref.is_a?(String) && @ref.match?(/\A[0-9a-f]{40,64}\z/)

        git('rev-parse', '--verify', '--end-of-options', "#{@ref}^{commit}").strip
      end

      def result(sha, trusted, inventory, config)
        status = status_for(inventory, config)
        PrivateSourceResult.new(root: @root, common_git_dir: common_git_dir, ref: sha,
                                trusted_source: trusted ? 'present' : 'absent', status:,
                                inventory: inventory.entries, blockers: @blockers.freeze,
                                candidate_config: status == 'complete' ? config : nil)
      end

      def status_for(inventory, config)
        return 'unsafe_file' if inventory.unsafe
        return 'conflicting' if @conflict
        return 'absent' if inventory.entries.empty?

        @blockers.empty? && config ? 'complete' : 'partial'
      end

      def verify_worktree!
        top = File.realpath(git('rev-parse', '--show-toplevel').strip)
        raise Error, "#{@root} is not the Git worktree root" unless top == @root
      end

      def common_git_dir = File.realpath(File.expand_path(git('rev-parse', '--git-common-dir').strip, @root))

      def git(*args)
        output, error, status = Open3.capture3('git', '-C', @root, *args)
        raise Error, "Cannot inspect private source: git #{args.first} failed: #{error.strip}" unless status.success?

        output
      end

      def inspect_conflicts(trusted, indexed, committed, entries)
        conflict!("#{Paths::CONTRACT} conflicts with private #{Paths::NEW_CONTRACT}") if legacy_collision?(entries)
        private_tracked = (indexed | committed).select { |path| private_path?(path) }
        conflict!("tracked private files: #{private_tracked.join(', ')}") unless private_tracked.empty?
        conflict!("Trusted default branch already has #{trusted.contract}") if trusted && entries.any?
      end

      def private_path?(path) = path.split('/').first(2).join('/') == PrivateInventory::DIRECTORY

      def legacy_collision?(entries)
        legacy = File.join(@root, Paths::CONTRACT)
        entries.any? && (File.exist?(legacy) || File.symlink?(legacy))
      end

      def conflict!(message)
        @blockers << message
        @conflict = true
      end

      def load_candidate(inventory, committed)
        return if inventory.unsafe || @conflict

        entries = inventory.entries
        return if entries.empty?

        unless entries.any? { |entry| entry[:path] == Paths::NEW_CONTRACT && entry[:type] == 'regular' }
          @blockers << "Missing #{Paths::NEW_CONTRACT}"
          return
        end

        validate_candidate(committed)
      end

      def validate_candidate(committed)
        config = RepositoryConfig.load(root: @root)
        inspect_optional_pair(config)
        inspect_prompt_dependencies(config, committed)
        config
      rescue Error => e
        @blockers << e.message
        nil
      end

      def inspect_optional_pair(config)
        return if config.commands.key?('validate_local') == config.commands.key?('trigger_hosted_ci')

        @blockers << 'Private validate-local and trigger-hosted-ci must be present together'
      end

      def inspect_prompt_dependencies(config, committed)
        RepositoryConfig.prompt_files(review: config.review, opening: config.opening_check).each do |label, path|
          @blockers << "#{label} #{path} is outside #{PrivateInventory::DIRECTORY} and not tracked" unless
            committed_prompt?(path, committed)
        end
      end

      def committed_prompt?(path, committed)
        lexical = relative_path(File.expand_path(path, @root))
        return true if lexical.start_with?("#{PrivateInventory::DIRECTORY}/")

        resolved = relative_path(File.realpath(File.join(@root, path)))
        committed.include?(lexical) && committed.include?(resolved) &&
          PrivatePathHops.uncommitted(root: @root, path:, committed:).empty?
      end

      def relative_path(path) = Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
    end
  end
end
