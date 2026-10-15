# frozen_string_literal: true

require 'open3'
require 'time'
require_relative '../error'

module Shaka
  # Finds the pull request commit a rebase made from a reviewed commit that was never pushed. A rebase
  # keeps a commit's subject and author date, so the local commit's pair names its copy when exactly
  # one pull request commit shares it. Without the local commit or a unique match, there is none.
  class LocalReviewRebasedCommits
    SHA = /\A\h{40}\z/

    def initialize(github, repository, root: Dir.pwd)
      @github = github
      @repository = repository
      @root = root
      @found = {}
    end

    def call(sha)
      @found.fetch(sha) do
        local = local_identity(sha)
        matches = local ? pull_commits.select { |commit| identity(commit) == local } : []
        @found[sha] = matches.one? ? matches.first.fetch('sha') : nil
      end
    end

    private

    def local_identity(sha)
      return unless sha.match?(SHA)

      output, _error, status = Open3.capture3('git', '-C', @root, 'log', '-1', '--format=%s%x00%aI', sha)
      return unless status.success?

      subject, date = output.chomp.split("\0", 2)
      [subject, Time.iso8601(date)]
    rescue ArgumentError, SystemCallError
      nil
    end

    def identity(commit)
      subject = commit.dig('commit', 'message').to_s.lines.first.to_s.strip
      [subject, Time.iso8601(commit.dig('commit', 'author', 'date'))]
    rescue ArgumentError, TypeError
      nil
    end

    # GitHub lists at most 250 commits for a pull request; a rebased copy beyond that is not found.
    def pull_commits
      @pull_commits ||= begin
        listed = @github.api("repos/#{@repository}/pulls/#{@github.number}/commits?per_page=100")
        listed.is_a?(Array) ? listed : []
      end
    end
  end
end
