# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative '../workflow_version'
require_relative 'paths'

module Shaka
  module Configuration
    # Read-only boundary: no reset, unstaging, or edits to the user's index.
    class FeatureGuard
      FLOWS = %w[feature setup migration].freeze
      LEGACY = [Paths::CONTRACT, Paths::POINTER, Paths::LEGACY_README, Paths::REPOSITORY_ALLOWLIST].freeze

      def self.check(root:, base:, head:, flow: 'feature')
        new(root:, base:, head:, flow:).check
      end

      def initialize(root:, base:, head:, flow:)
        @root = root
        @base = base
        @head = head
        @flow = flow
      end

      def check
        raise Error, 'Publication flow must be feature, setup, or migration' unless FLOWS.include?(@flow)

        changed = changed_paths
        if @flow == 'feature' && changed.any?
          raise Error, 'Feature PR contains Shaka configuration changes; preserve these edits and use a separate ' \
                       'setup/migration PR. Private paths are REDACTED.'
        end

        { 'status' => 'clear', 'flow' => @flow, 'configuration_changes' => changed.any? }
      end

      private

      def changed_paths
        # Resolve even for setup/migration; a typo must never skip comparison.
        base = git('rev-parse', '--verify', '--end-of-options', "#{@base}^{commit}").strip
        head = git('rev-parse', '--verify', '--end-of-options', "#{@head}^{commit}").strip
        paths = [git('diff', '--name-only', '--no-renames', '-z', "#{base}...#{head}", '--'),
                 git('diff', '--cached', '--name-only', '--no-renames', '-z', 'HEAD', '--'),
                 git('diff', '--name-only', '--no-renames', '-z', '--'),
                 git('ls-files', '--others', '--exclude-standard', '-z')]
        paths.flat_map { |output| output.split("\0") }.uniq.select { |path| configuration?(path) }
      end

      def configuration?(path)
        LEGACY.include?(path) || path == '.agents/shaka' || path.start_with?('.agents/shaka/', '.agents/bin/')
      end

      def git(*)
        output, error, status = Open3.capture3(WorkflowVersion::GIT_ENVIRONMENT, 'git', '-C', @root, *)
        raise Error, "Cannot inspect feature boundary: #{error.strip}" unless status.success?

        output
      end
    end
  end
end
