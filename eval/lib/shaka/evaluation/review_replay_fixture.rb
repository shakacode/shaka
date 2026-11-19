# frozen_string_literal: true

require 'open3'

module Shaka
  module Evaluation
    # A separate object database exposes historical source and selected review settings only.
    class ReviewReplayFixture
      SHA = /\A[0-9a-f]{40}\z/
      GIT_CONFIG = %w[-c core.hooksPath=/dev/null -c core.fsmonitor=false].freeze
      GIT_ENVIRONMENT = %w[GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
                           GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE
                           GIT_INDEX_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX
                           GIT_SHALLOW_FILE GIT_COMMON_DIR GIT_CEILING_DIRECTORIES].to_h { |name| [name, nil] }.freeze

      def initialize(source:, root:, row:)
        @source = source
        @root = root
        @base, @head = row.values_at('base', 'head')
      end

      def prepare(criteria)
        git(@root, 'init', '--quiet', '--template=')
        git(@root, 'fetch', '--quiet', '--no-tags', @source, @head)
        merge_base = git(@root, 'merge-base', @base, @head).strip
        raise ArgumentError, 'Recorded base is not an ancestor of the reviewed commit' unless merge_base == @base

        snapshot = criteria_commit(criteria)
        git(@root, 'checkout', '--quiet', '--force', '--detach', @head)
        snapshot
      end

      def self.entries(source, ref)
        output, error, status = Open3.capture3(GIT_ENVIRONMENT, 'git', '-C', source, 'ls-tree', '-r', '-z', ref,
                                               stdin_data: '', binmode: true)
        raise IOError, "Cannot read criteria commit: #{error.strip}" unless status.success?

        output.split("\0").select { |entry| regular_settings?(entry) }
      end

      def self.agents_path?(path)
        path == 'AGENTS.md' || path.end_with?('/AGENTS.md')
      end

      def self.regular_settings?(entry)
        meta, path = entry.split("\t", 2)
        return false unless agents_path?(path) || path.start_with?('.agents/shaka/')
        return true if meta.start_with?('100644 blob ', '100755 blob ')

        raise IOError, 'Use regular files for the projected reviewer settings and criteria'
      end

      private

      def criteria_commit(ref)
        entries = self.class.entries(@source, ref).filter_map { |entry| copy_entry(entry) }
        git(@root, 'update-index', '-z', '--index-info', input: entries.join)
        tree = git(@root, 'write-tree').strip
        git(@root, '-c', 'user.name=Shaka Eval', '-c', 'user.email=eval@example.invalid',
            'commit-tree', tree, '-m', 'Review settings').strip
      end

      def copy_entry(entry)
        meta, path = entry.split("\t", 2)
        mode, _type, oid = meta.split

        data = git(@source, 'cat-file', 'blob', oid)
        blob = git(@root, 'hash-object', '-w', '--stdin', input: data).strip
        "#{mode} #{blob}\t#{path}\0"
      end

      def git(root, *args, input: '')
        output, error, status = Open3.capture3(GIT_ENVIRONMENT, 'git', *GIT_CONFIG, '-C', root, *args,
                                               stdin_data: input, binmode: true)
        raise IOError, "git #{args.first} failed: #{error.strip}" unless status.success?

        output
      end
    end
  end
end
