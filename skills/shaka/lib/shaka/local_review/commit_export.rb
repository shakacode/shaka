# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative '../error'

module Shaka
  # Gives restricted Claude the reviewed commit's files without untracked files, Git history, or links out.
  module LocalReviewCommitExport
    READERS = %w[anthropic/claude].freeze
    # Regular files only: links can point anywhere on disk and submodules hold no files here.
    ENTRY = /\A100(?:644|755) blob (\h+)\t(.+)\z/m
    # Bounds how many blobs one Git call holds in memory at a time.
    BATCH = 200

    private

    def with_commit_export
      return yield unless READERS.include?(reviewer)

      Dir.mktmpdir('shaka-review-commit-') do |directory|
        export_commit(File.realpath(directory))
        yield
      ensure
        @options.delete(:commit_export)
      end
    end

    # Raw blobs, not a checkout: checkout filters, which the candidate's attributes select, could
    # run commands or write decrypted or downloaded content that the commit does not hold.
    def export_commit(directory)
      commit_entries.each_slice(BATCH) do |entries|
        blobs = capture(git_executable, '-C', root, 'cat-file', '--batch',
                        stdin: entries.map { |id, _| "#{id}\n" }.join).b
        write_blobs(directory, entries, blobs)
      end
      @options[:commit_export] = directory
    end

    # Path names are bytes, not necessarily UTF-8.
    def commit_entries
      capture(git_executable, '-C', root, 'ls-tree', '-r', '-z', '--full-tree', head)
        .b.split("\0").filter_map { |entry| entry.match(ENTRY)&.captures }
    end

    def write_blobs(directory, entries, blobs)
      entries.reduce(0) do |offset, (id, path)|
        content, following = blob_at(blobs, offset, id)
        write_file(directory, path, content)
        following
      end
    end

    # Returns the blob that starts at offset and where the next one starts, or refuses a short read.
    def blob_at(blobs, offset, id)
      header_end = blobs.index("\n", offset)
      size = header_end && blobs.byteslice(offset...header_end)[/\A#{id} blob (\d+)\z/, 1]&.to_i
      content = size && blobs.byteslice(header_end + 1, size)
      return [content, header_end + size + 2] if
        content&.bytesize == size && blobs.byteslice(header_end + 1 + size) == "\n"

      raise Shaka::Error, "Git returned an incomplete blob #{id} for the commit export"
    end

    # Paths that collide on this filesystem, such as names or directories differing only in case,
    # stop the export: the file's real path must keep the spelling the commit gave it.
    def write_file(directory, path, content)
      check_path!(path)
      target = File.join(directory.b, path)
      FileUtils.mkdir_p(File.dirname(target))
      File.open(target, File::WRONLY | File::CREAT | File::EXCL | File::BINARY) { |file| file.write(content) }
      raise Errno::EEXIST, path unless File.realpath(target).b == target
    rescue Errno::EEXIST, Errno::ENOTDIR, Errno::EISDIR, Errno::EILSEQ
      raise Shaka::Error, "Commit export cannot hold #{path.inspect} on this filesystem: it collides with " \
                          'another committed path or uses a name the filesystem refuses'
    end

    def check_path!(path)
      return unless path.start_with?('/') || path.split('/').intersect?(['', '.', '..'])

      raise Shaka::Error, "Commit export path leaves the export: #{path.inspect}"
    end
  end
end
