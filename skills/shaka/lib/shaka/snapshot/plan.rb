# frozen_string_literal: true

require_relative '../error'
require_relative 'changes'
require_relative 'screen'
require_relative 'tree'

module Shaka
  class Snapshot
    # Decides what one snapshot would publish, so it can be read before anything is pushed.
    #
    # What the push sends is the list this prints and nothing else, because the commit it
    # builds has no parent. The screen therefore covers the whole publication, and the list
    # is short enough that reading it is real review rather than a formality.
    class Plan
      SEPARATOR = "\0"

      def initialize(root:, branch:, remote_head:, git:)
        @root = root
        @branch = branch
        @remote_head = remote_head
        @git = git
      end

      def to_h
        { 'branch' => @branch, 'published' => false, 'adds' => readable(publishable),
          'removes' => readable(removals), 'held_back' => readable(screen.excluded),
          'held_back_submodules' => readable(nested), 'unpushed_commits' => unpushed_commits,
          'tree' => tree, 'digest' => digest }
      end

      private

      # Git works in path bytes and the report is JSON, so what the reader sees is scrubbed
      # while the commands keep the bytes. Only held-back paths can be unreadable, because
      # the screen refuses to publish a name it cannot render.
      def readable(paths) = paths.map { |path| path.scrub('?') }

      # Deletions describe the checkout rather than the snapshot: with no parent there is
      # nothing to delete from. They are reported so the recovery note can record them.
      def removals = changes.removed - surviving

      def tree = @tree ||= Tree.new(git: @git).build(publishable)

      # The digest names the exact tree, so editing a listed file invalidates it.
      def digest = publishable.empty? ? 'none' : tree[0, 12]

      def screen = @screen ||= Screen.new((changes.added + surviving).uniq.sort)

      def publishable = screen.included - nested

      def nested = @nested ||= screen.included.select { |path| nested?(path) }

      # Git reports path bytes, which need not be valid UTF-8, so the stream is split as
      # bytes and each path is labelled UTF-8 afterwards. A name that is not valid UTF-8
      # then reaches the screen and the report as its own bytes rather than raising.
      def changes
        @changes ||= Changes.new(split(@git.call('status', '--porcelain', '-uall', '-z')))
      end

      def split(output)
        output.b.split(SEPARATOR).map { |entry| entry.force_encoding(Encoding::UTF_8) }
      end

      # A conflicted path can be reported as deleted while the resolution is still on disk,
      # and a symlink is a resolution like any other, including a broken one or one naming a
      # directory. A directory that took the deleted file's name is not that file, though,
      # and adding it would stage the children the checkout ignores.
      def surviving
        @surviving ||= changes.removed.select { |path| resolved?(File.join(@root, path)) }
      end

      def resolved?(path) = File.symlink?(path) || File.file?(path)

      # A snapshot does not carry local commits, so the note must say they exist. This
      # describes the checkout rather than gating the push: the remote's own answer for this
      # branch is the only comparison, and UNKNOWN when it has never advertised one.
      def unpushed_commits
        return ['UNKNOWN'] if @remote_head.empty?

        @git.call('log', '--oneline', '--no-decorate', "#{@remote_head}..HEAD").split("\n")
      rescue Error
        ['UNKNOWN']
      end

      # Neither a tracked submodule nor an untracked embedded repository can travel in this
      # commit: the superproject would record one gitlink and leave the work behind. With
      # -uall, only an embedded repository is reported as a directory.
      def nested?(path) = path.end_with?('/') || submodules.include?(path)

      def submodules
        @submodules ||= split(@git.call('ls-files', '--stage', '-z')).filter_map do |entry|
          entry.split("\t", 2).last if entry.start_with?('160000 ')
        end
      end
    end
  end
end
