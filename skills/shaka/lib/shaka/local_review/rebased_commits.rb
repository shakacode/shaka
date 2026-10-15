# frozen_string_literal: true

require 'open3'
require 'time'
require_relative '../error'

module Shaka
  # Finds the pull request commit a rebase made from a reviewed commit that was never pushed. A rebase
  # keeps a commit's subject and author date, so those pick the candidates; the copy must also make the
  # same change, by `git patch-id`, so an amended commit with new content never counts. Without the
  # local commits, a unique match, or a readable commit list, there is no copy and the SHA stays plain.
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
      change = local && patch_id(sha)
      return unless change

      copies = pull_commits.select { |commit| identity(commit) == local && patch_id(commit['sha']) == change }
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

    def patch_id(sha)
      return unless sha.to_s.match?(SHA)

      diff, _error, status = Open3.capture3('git', '-C', @root, 'diff-tree', '-p', '--root', sha)
      return unless status.success? && !diff.empty?

      output, _error, status = Open3.capture3('git', '-C', @root, 'patch-id', '--stable', stdin_data: diff)
      output.split.first if status.success?
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
