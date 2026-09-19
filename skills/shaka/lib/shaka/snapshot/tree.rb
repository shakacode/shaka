# frozen_string_literal: true

require 'tmpdir'
require_relative '../error'

module Shaka
  class Snapshot
    # Builds and commits the tree a snapshot would publish, without touching the checkout.
    #
    # A temporary index is used, so the working tree and the real index are untouched, and
    # the same tree answers both what a plan would publish and what a push commits.
    class Tree
      # A host that never configured a git identity can still save its work: this branch is
      # not for review or merge, so a stand-in name beats refusing to keep the work.
      IDENTITY = { 'GIT_AUTHOR_NAME' => 'shaka snapshot', 'GIT_AUTHOR_EMAIL' => 'snapshot@localhost',
                   'GIT_COMMITTER_NAME' => 'shaka snapshot',
                   'GIT_COMMITTER_EMAIL' => 'snapshot@localhost' }.freeze

      def initialize(git:)
        @git = git
      end

      # The confirmed plan already named its tree, so publishing commits that exact tree.
      def commit(tree:, parent:, message:)
        @git.call('commit-tree', tree, '-p', parent, '-m', message, environment: identity).strip
      end

      def build(adds, removes)
        Dir.mktmpdir('shaka-snapshot') do |dir|
          index = File.join(dir, 'index')
          @git.call('read-tree', 'HEAD', index: index)
          @git.call('add', '--force', '--', *adds, index: index) unless adds.empty?
          @git.call('update-index', '--force-remove', '--', *removes, index: index) unless removes.empty?
          @git.call('write-tree', index: index).strip
        end
      end

      def parent = @git.call('rev-parse', 'HEAD').strip

      private

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
