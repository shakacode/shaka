# frozen_string_literal: true

require_relative '../error'
require_relative 'changes'
require_relative 'screen'
require_relative 'tree'

module Shaka
  class Snapshot
    # Decides what one snapshot would publish, so it can be read before anything is pushed.
    class Plan
      SEPARATOR = "\0"

      def initialize(root:, branch:, remote_head:, git:)
        @root = root
        @branch = branch
        @remote_head = remote_head
        @git = git
      end

      def to_h
        { 'branch' => @branch, 'published' => false, 'adds' => publishable,
          'removes' => removals, 'held_back' => screen.excluded,
          'held_back_submodules' => nested, 'unpushed_commits' => unpushed_commits,
          'tree' => tree, 'parent' => parent, 'digest' => digest }
      end

      private

      def removals = changes.removed - surviving

      def builder = @builder ||= Tree.new(git: @git)

      def tree = @tree ||= builder.build(publishable, removals)

      def parent = @parent ||= builder.parent

      # The digest names the exact tree and parent, so editing a listed file invalidates it.
      def digest
        return 'none' if publishable.empty? && removals.empty?

        "#{tree[0, 12]}.#{parent[0, 7]}"
      end

      def screen = @screen ||= Screen.new((changes.added + surviving).uniq.sort)

      def publishable = screen.included - nested

      def nested = @nested ||= screen.included.select { |path| nested?(path) }

      def changes
        @changes ||= Changes.new(@git.call('status', '--porcelain', '-uall', '-z').split(SEPARATOR))
      end

      # A conflicted path can be reported as deleted while the file is still on disk.
      def surviving
        @surviving ||= changes.removed.select { |path| File.exist?(File.join(@root, path)) }
      end

      # The push carries every object the snapshot's parent needs, so name that history.
      # A branch the remote has never seen still has commits nobody published.
      def unpushed_commits
        range = @remote_head.empty? ? ['HEAD', '--not', '--remotes'] : ["#{@remote_head}..HEAD"]
        @git.call('log', '--oneline', '--no-decorate', *range).split("\n")
      rescue Error
        ['UNKNOWN']
      end

      # Neither a tracked submodule nor an untracked embedded repository can travel in this
      # commit: the superproject would record one gitlink and leave the work behind. With
      # -uall, only an embedded repository is reported as a directory.
      def nested?(path) = path.end_with?('/') || submodules.include?(path)

      def submodules
        @submodules ||= @git.call('ls-files', '--stage', '-z').split(SEPARATOR).filter_map do |entry|
          entry.split("\t", 2).last if entry.start_with?('160000 ')
        end
      end
    end
  end
end
