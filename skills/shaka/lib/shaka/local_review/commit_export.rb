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
      entries = commit_entries
      blobs = capture(git_executable, '-C', root, 'cat-file', '--batch',
                      stdin: entries.map { |id, _| "#{id}\n" }.join).b
      write_blobs(directory, entries, blobs)
      @options[:commit_export] = directory
    end

    def commit_entries
      capture(git_executable, '-C', root, 'ls-tree', '-r', '-z', '--full-tree', head)
        .split("\0").filter_map { |entry| entry.match(ENTRY)&.captures }
    end

    def write_blobs(directory, entries, blobs)
      offset = 0
      entries.each do |id, path|
        header_end = blobs.index("\n", offset)
        header = header_end && blobs.byteslice(offset...header_end).match(/\A#{id} blob (\d+)\z/)
        raise Shaka::Error, "Git returned no blob #{id} for the commit export" unless header

        size = header[1].to_i
        write_file(directory, path, blobs.byteslice(header_end + 1, size))
        offset = header_end + 1 + size + 1
      end
    end

    # Paths that collide on this filesystem, such as names differing only in case, stop the export.
    def write_file(directory, path, content)
      target = File.expand_path(path, directory)
      raise Shaka::Error, "Commit export path leaves the export: #{path}" unless target.start_with?("#{directory}/")

      FileUtils.mkdir_p(File.dirname(target))
      File.open(target, File::WRONLY | File::CREAT | File::EXCL | File::BINARY) { |file| file.write(content) }
    rescue Errno::EEXIST, Errno::ENOTDIR, Errno::EISDIR
      raise Shaka::Error, "Commit export cannot hold both colliding paths for #{path} on this filesystem"
    end
  end
end
