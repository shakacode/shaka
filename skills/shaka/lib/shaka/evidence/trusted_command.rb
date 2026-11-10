# frozen_string_literal: true

require_relative '../configuration'
require_relative '../error'

module Shaka
  module Evidence
    # Runs a fixed command the candidate lacks because its branch predates the command directory.
    # The trusted commit's copy sits at its usual path for the run, so it finds the checkout the
    # same way, and everything this created is removed afterward.
    class TrustedCommand
      # Runs the block with the trusted copy in place when the evidence run's candidate lacks the command.
      def self.around(context, &)
        return yield unless needed?(context)

        new(*context.values_at(:root, :ref, :path)).with(&)
      end

      # The result field that tells a reader the default branch supplied the command.
      def self.source(context) = needed?(context) ? { 'command_source' => 'trusted_ref' } : {}

      # Settings load without candidate commands only when the branch predates the command directory.
      def self.needed?(context)
        root, path = context.values_at(:root, :path)
        return false if File.exist?(File.join(root, path)) || File.symlink?(File.join(root, path))
        raise Error, "#{path} is missing from this checkout" unless context.fetch(:kind) == 'trusted/team'

        true
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
        File.delete(target) if @written && File.file?(target)
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

      # The run may already have removed a directory this created, as `git clean -fdx` does.
      def removable?(directory) = File.directory?(directory) && Dir.empty?(directory)
      def target = File.join(@root, @path)
      def parent(index) = File.join(@root, *File.dirname(@path).split('/').first(index + 1))
      def relative(directory) = directory.delete_prefix("#{@root}/")
    end
  end
end
