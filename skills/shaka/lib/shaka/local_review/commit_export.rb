# frozen_string_literal: true

require 'find'
require 'tmpdir'
require_relative '../error'

module Shaka
  # Gives restricted Claude the reviewed commit's files without untracked files, Git history, or links out.
  module LocalReviewCommitExport
    READERS = %w[anthropic/claude].freeze

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

    # A private index keeps the checkout's own index untouched, and checkout-index ignores the
    # export-ignore and export-subst attributes a candidate could use to hide or rewrite files.
    # Without --force it refuses paths that collide on this filesystem rather than overwrite one.
    # The index sits beside the export, not inside it, so the reviewer never sees it.
    def export_commit(directory)
      files = File.join(directory, 'files')
      Dir.mkdir(files)
      env = { 'GIT_INDEX_FILE' => File.join(directory, 'index') }
      capture(git_executable, '-C', root, 'read-tree', head, env:)
      capture(git_executable, '-C', root, 'checkout-index', '--all', "--prefix=#{files}/", env:)
      remove_links(files)
      @options[:commit_export] = files
    end

    # A committed link can point anywhere on disk; the reviewer reads the diff for its target.
    def remove_links(directory)
      Find.find(directory) { |path| File.unlink(path) if File.symlink?(path) }
    end
  end
end
