# frozen_string_literal: true

require_relative '../configuration'
require_relative '../error'
require_relative 'candidate_tree'

module Shaka
  module Evidence
    # Runs a fixed command the candidate lacks because its branch predates the command directory.
    # The trusted commit's copy sits at its usual path for the run, so it finds the checkout the
    # same way, and everything this created is removed afterward.
    class TrustedCommand
      # Runs the block with the trusted copy in place when the run decided to use it. The block gets
      # the checkout and the tree to watch during the check: the tested tree, plus the copy while it is in place.
      def self.around(context, tree)
        root = context.fetch(:root)
        return yield root, tree unless context.fetch(:trusted_copy)

        new(root, *context.values_at(:ref, :path)).with { yield root, CandidateTree.capture(root:) }
      end

      # The result field that tells a reader the default branch supplied the command.
      def self.source(context) = context.fetch(:trusted_copy) ? { 'command_source' => 'trusted_ref' } : {}

      # Decided once before the run, by the condition that lets settings load without candidate
      # commands: no command directory at all.
      def self.needed?(root:, kind:)
        directory = File.join(root, Configuration::Paths::COMMAND_DIRECTORY)
        return false if File.exist?(directory) || File.symlink?(directory)
        return true if kind == 'trusted/team'

        raise Error, "#{Configuration::Paths::COMMAND_DIRECTORY} is missing from this checkout"
      end

      def initialize(root, sha, path)
        @root = root
        @path = path
        @text = Configuration.trusted_command(root:, sha:, path:)
      end

      def with
        @created = []
        create_directories
        write_copy
        yield
      ensure
        File.delete(target) if @written && in_place?
        @created.reverse_each { |directory| Dir.rmdir(directory) if removable?(directory) }
      end

      private

      # Marks the copy written once the file exists, so a failed write still removes it.
      def write_copy
        File.open(target, File::WRONLY | File::CREAT | File::EXCL, 0o755) do |file|
          @written = true
          file.write(@text)
        end
      end

      # Refuses any symlinked or non-directory parent, so the copy cannot land outside the checkout.
      def create_directories
        parents = File.dirname(@path).split('/').each_index.map { |index| parent(index) }
        parents.each do |directory|
          raise Error, "#{relative(directory)} must be a real directory, not a symlink" if File.symlink?(directory)
          next if File.directory?(directory)
          raise Error, "#{relative(directory)} must be a real directory" if File.exist?(directory)

          Dir.mkdir(directory)
          @created << directory
        end
      end

      # The run may have removed the copy or swapped any directory above it for a symlink.
      def in_place? = File.file?(target) && unmoved?(File.dirname(target))

      # The run may already have removed a directory this created, as `git clean -fdx` does.
      def removable?(directory) = File.directory?(directory) && unmoved?(directory) && Dir.empty?(directory)

      # True when no component of the path now leads outside its place in the checkout.
      def unmoved?(directory) = File.realpath(directory) == File.join(File.realpath(@root), relative(directory))
      def target = File.join(@root, @path)
      def parent(index) = File.join(@root, *File.dirname(@path).split('/').first(index + 1))
      def relative(directory) = directory.delete_prefix("#{@root}/")
    end
  end
end
