# frozen_string_literal: true

require 'open3'

module Shaka
  module Evaluation
    # A separate object database exposes historical source and selected review settings only.
    class ReviewReplayFixture
      SHA = /\A[0-9a-f]{40}\z/
      GIT_CONFIG = %w[-c core.hooksPath=/dev/null -c core.fsmonitor=false].freeze

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

      def self.settings_entries(source, ref)
        output, error, status = Open3.capture3('git', '-C', source, 'ls-tree', '-r', '-z', ref,
                                               stdin_data: '', binmode: true)
        raise IOError, "Cannot read criteria commit: #{error.strip}" unless status.success?

        output.split("\0").select { |entry| entry.split("\t", 2).last.start_with?('.agents/shaka/') }
      end

      private

      def criteria_commit(ref)
        entries = git(@source, 'ls-tree', '-r', '-z', ref).split("\0").filter_map { |entry| copy_entry(entry) }
        git(@root, 'update-index', '-z', '--index-info', input: entries.join)
        tree = git(@root, 'write-tree').strip
        git(@root, '-c', 'user.name=Shaka Eval', '-c', 'user.email=eval@example.invalid',
            'commit-tree', tree, '-m', 'Review settings').strip
      end

      def copy_entry(entry)
        meta, path = entry.split("\t", 2)
        mode, type, oid = meta.split
        return unless type == 'blob' && criteria_path?(path)

        data = git(@source, 'cat-file', 'blob', oid)
        blob = git(@root, 'hash-object', '-w', '--stdin', input: data).strip
        "#{mode} #{blob}\t#{path}\0"
      end

      def criteria_path?(path)
        path == 'AGENTS.md' || path.end_with?('/AGENTS.md') || path.start_with?('.agents/shaka/')
      end

      def git(root, *args, input: '')
        output, error, status = Open3.capture3('git', *GIT_CONFIG, '-C', root, *args, stdin_data: input, binmode: true)
        raise IOError, "git #{args.first} failed: #{error.strip}" unless status.success?

        output
      end
    end
  end
end
