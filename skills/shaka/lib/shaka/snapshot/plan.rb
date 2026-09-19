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
          'unpushed_held_back' => unpushed_held_back,
          'tree' => tree, 'parent' => parent, 'digest' => digest }
      end

      private

      def removals = changes.removed - surviving

      def builder = @builder ||= Tree.new(git: @git)

      def tree = @tree ||= builder.build(publishable, removals)

      def parent = @parent ||= builder.parent

      # The digest names the exact tree and parent, so editing a listed file invalidates it.
      def digest
        return 'none' if publishable.empty? && removals.empty? && unpushed_commits.empty?

        "#{tree[0, 12]}.#{parent[0, 7]}"
      end

      def screen = @screen ||= Screen.new((changes.added + surviving).uniq.sort)

      def publishable = screen.included - nested

      def nested = @nested ||= screen.included.select { |path| nested?(path) }

      def changes
        @changes ||= Changes.new(@git.call('status', '--porcelain', '-uall', '-z').split(SEPARATOR))
      end

      # A conflicted path can be reported as deleted while the file is still on disk. A
      # directory that took the deleted file's name is not that file, and adding it would
      # stage the children the checkout ignores.
      def surviving
        @surviving ||= changes.removed.select { |path| File.file?(File.join(@root, path)) }
      end

      # The push carries every object the snapshot's parent needs, so name that history.
      # A branch the remote has never seen still has commits nobody published.
      def unpushed_commits
        @unpushed_commits ||= @git.call('log', '--oneline', '--no-decorate', *range).split("\n")
      rescue Error
        @unpushed_commits = ['UNKNOWN']
      end

      # The snapshot commits on top of the local head, so an unpushed commit travels with the
      # push and cannot be held back. Naming its screened paths lets publishing refuse
      # instead, since the only other way to hold them back is to rewrite that history.
      def unpushed_held_back
        paths = unpushed_paths
        paths == ['UNKNOWN'] ? paths : Screen.new(paths).excluded
      end

      def unpushed_paths
        @git.call('log', '--name-only', '--pretty=format:', *range).split("\n").reject(&:empty?).uniq.sort
      rescue Error
        ['UNKNOWN']
      end

      def range = @remote_head.empty? ? ['HEAD', '--not', '--remotes'] : ["#{@remote_head}..HEAD"]

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
