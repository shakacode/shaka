# frozen_string_literal: true

require 'tmpdir'
require_relative '../error'

module Shaka
  class Snapshot
    # Builds the tree a snapshot would publish, without touching the checkout.
    #
    # A temporary index is used, so the working tree and the real index are untouched, and
    # the same tree answers both what a plan would publish and what a push commits.
    class Tree
      def initialize(git:)
        @git = git
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
    end
  end
end
