# frozen_string_literal: true

require 'json'
require 'tempfile'
require_relative 'git_memo'
require_relative 'layout'
require_relative 'private_git_paths'

module Shaka
  module Configuration
    # Stores an explicit source selection, never another copy of repository settings.
    # The Git worktree directory cannot be supplied by a tracked candidate file.
    class SettingsPreview
      def self.ref(root:) = new(root:).status['settings_ref']

      def self.load_config(root:, ref:, candidate_commands: true)
        directory = Paths.at(root, Paths::COMMAND_DIRECTORY)
        if candidate_commands && !File.directory?(directory)
          raise Error, 'Prepare the task worktree’s Shaka command wrappers before using a settings preview.'
        end

        require_relative '../trusted_config_source'
        TrustedConfigSource.load(root:, ref:, candidate_commands:)
      end

      def initialize(root:)
        @root = File.realpath(root)
        @directory = GitMemo.fetch([:git_dir, @root]) { git('rev-parse', '--absolute-git-dir').strip }
        @path = File.join(@directory, 'shaka-settings-preview.json')
      end

      def start(ref, default_ref: nil)
        validate_ref!(ref)
        branch = current_branch
        raise Error, 'Create a task branch before starting a settings preview.' if branch.empty?

        # Validate with the existing schema and the task's executable entry points.
        self.class.load_config(root: @root, ref:)
        first_setup = missing_team_settings?(default_ref) || status['first_setup']
        record = { 'version' => 1, 'branch' => branch, 'ref' => ref }
        record['first_setup'] = true if first_setup
        save(record)
        status
      end

      def save(record)
        Tempfile.create('.shaka-settings-preview-', @directory) do |file|
          file.write(JSON.generate(record))
          file.close
          File.rename(file.path, @path)
        end
      end
      private :save

      def stop
        File.unlink(@path) if File.exist?(@path) || File.symlink?(@path)
        { 'status' => 'inactive' }
      end

      def status
        record = read_record
        return { 'status' => 'inactive' } unless record
        return { 'status' => 'inactive', 'reason' => 'The task branch changed.' } unless
          record['branch'] == current_branch

        validate_ref!(record['ref'])
        { 'status' => 'active', 'settings_ref' => record['ref'], 'grants_policy' => true,
          'grants_merge_authority' => false }.tap do |result|
          result['first_setup'] = true if record['first_setup'] == true
        end
      end

      private

      def missing_team_settings?(ref)
        return false unless ref

        validate_ref!(ref)
        return true unless Layout.commit(root: @root, sha: ref, allow_missing: true)

        TrustedConfigSource.load(root: @root, ref:, candidate_commands: false)
        false
      end

      def read_record
        return unless File.exist?(@path) || File.symlink?(@path)

        check_file!

        record = JSON.parse(File.read(@path))
        unless record.is_a?(Hash) && record['version'] == 1 && record['branch'].is_a?(String)
          raise Error, 'Invalid settings preview selection; stop the preview and select it again.'
        end

        record
      rescue JSON::ParserError
        raise Error, 'Invalid settings preview selection; stop the preview and select it again.'
      end

      def check_file!
        raise Error, 'Settings preview selection must be a regular file.' unless
          File.file?(@path) && !File.symlink?(@path) && File.size(@path) <= 16_384
      end

      def current_branch = git('branch', '--show-current').strip

      def validate_ref!(ref)
        unless ref.is_a?(String) && ref.match?(/\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/)
          raise Error, 'Select a full settings commit SHA; moving branches are not preview sources.'
        end
        return if git('rev-parse', '--verify', '--end-of-options', "#{ref}^{commit}").strip == ref

        raise Error, 'Settings preview source must be a commit.'
      end

      def git(*)
        output, error, status = PrivateGitPaths.capture(@root, *)
        raise Error, "Cannot read settings preview: #{error.strip}" unless status.success?

        output
      end
    end
  end
end
