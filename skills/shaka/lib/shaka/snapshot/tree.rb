# frozen_string_literal: true

require 'tmpdir'
require_relative '../error'

module Shaka
  class Snapshot
    # Builds and commits the tree a snapshot publishes, without touching the checkout.
    #
    # The tree holds the listed files and nothing else, and the commit has no parent, so a
    # snapshot carries exactly what its plan named. Nothing reachable from the local head
    # travels with it: not an unpushed commit, not a merge resolution, not a file some other
    # remote once held. A temporary index keeps the working tree and the real index untouched.
    class Tree
      # A host that never configured a git identity can still save its work: this branch is
      # not for review or merge, so a stand-in name beats refusing to keep the work.
      IDENTITY = { 'GIT_AUTHOR_NAME' => 'shaka snapshot', 'GIT_AUTHOR_EMAIL' => 'snapshot@localhost',
                   'GIT_COMMITTER_NAME' => 'shaka snapshot',
                   'GIT_COMMITTER_EMAIL' => 'snapshot@localhost' }.freeze

      def initialize(git:)
        @git = git
      end

      # The index starts empty, so a path that was never listed cannot reach the tree.
      def build(paths)
        Dir.mktmpdir('shaka-snapshot') do |dir|
          index = File.join(dir, 'index')
          @git.call('add', '--force', '--', *paths, index:) unless paths.empty?
          @git.call('write-tree', index:).strip
        end
      end

      # The confirmed plan already named its tree, so publishing commits that exact tree.
      def commit(tree:, branch:)
        @git.call('commit-tree', tree, '-m', message(branch), environment: identity).strip
      end

      private

      def message(branch)
        "Snapshot unfinished work on #{branch}\n\n" \
          'Published by shaka snapshot. Not for review or merge. This commit has no parent ' \
          "and holds only the files the snapshot listed; the branch it came from is elsewhere.\n"
      end

      def identity = configured_identity? ? {} : IDENTITY

      # Git needs both fields, so a host that set only one has not configured an identity.
      def configured_identity? = %w[user.name user.email].all? { |field| configured?(field) }

      def configured?(field)
        !@git.call('config', '--get', field).strip.empty?
      rescue Error
        false
      end
    end
  end
end
