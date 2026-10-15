# frozen_string_literal: true

require 'open3'
require 'time'
require_relative '../error'

module Shaka
  # Finds the pull request commit a rebase made from a reviewed commit that was never pushed. A rebase
  # keeps a commit's subject and author date, so those pick the candidates; the copy must also make the
  # same change, byte for byte apart from line numbers and blob ids, so an amended commit with new
  # content, even whitespace, never counts. Without the local commits, a unique match, or a readable
  # commit list, there is no copy and the SHA stays plain.
  class LocalReviewRebasedCommits
    SHA = /\A\h{40}\z/

    def initialize(github, repository, root: Dir.pwd)
      @github = github
      @repository = repository
      @root = root
      @found = {}
    end

    def call(sha)
      @found.fetch(sha) { @found[sha] = copy_of(sha) }
    end

    private

    def copy_of(sha)
      local = local_identity(sha)
      change = local && change(sha)
      return unless change

      copies = pull_commits.select { |commit| identity(commit) == local && change(commit['sha']) == change }
      copies.one? ? copies.first.fetch('sha') : nil
    end

    def local_identity(sha)
      return unless sha.match?(SHA)

      output, _error, status = Open3.capture3('git', '-C', @root, 'log', '-1', '--format=%s%x00%aI', sha)
      return unless status.success?

      subject, date = output.chomp.split("\0", 2)
      [subject, Time.iso8601(date)]
    rescue ArgumentError, SystemCallError
      nil
    end

    # The commit's patch without the parts a rebase moves: blob ids and hunk line numbers.
    def change(sha)
      return unless sha.to_s.match?(SHA)

      diff, _error, status = Open3.capture3('git', '-C', @root, 'diff-tree', '-p', '--root', '--no-commit-id', sha)
      return unless status.success? && !diff.empty?

      diff.lines.reject { |line| line.start_with?('index ') }.map { |line| line.sub(/\A@@ [^@]* @@/, '@@') }.join
    rescue SystemCallError
      nil
    end

    def identity(commit)
      subject = commit.dig('commit', 'message').to_s.lines.first.to_s.strip
      [subject, Time.iso8601(commit.dig('commit', 'author', 'date'))]
    rescue ArgumentError, TypeError
      nil
    end

    # One page of up to 100 commits; a rebased copy beyond them is not found.
    def pull_commits
      @pull_commits ||= begin
        @github.api_list("repos/#{@repository}/pulls/#{@github.number}/commits?per_page=100")
      rescue Error
        []
      end
    end
  end
end
