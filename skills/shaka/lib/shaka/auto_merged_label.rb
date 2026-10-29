# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Marks a PR that `merge --auto` merged, so GitHub's PR list separates Auto merges from human ones.
  class AutoMergedLabel
    NAME = 'auto-merged'
    COLOR = '0E8A16'
    DESCRIPTION = 'Merged by the agent under Auto after every check on the head passed'
    NOT_FOUND = 404
    # 403: the caller may apply labels but not create them. 422: another run created it first.
    TOLERATED_CREATE_FAILURES = [403, 422].freeze

    def initialize(github, enabled: true)
      @github = github
      @enabled = enabled
    end

    # Adds the label outcome to a merge result. A queued PR has not merged yet, so it waits.
    def mark(result)
      return result unless @enabled

      result.merge('auto_merged_label' => result['state'] == 'MERGED' ? apply : 'not_applied_merge_queue')
    end

    private

    # The PR is already merged, so a failure is reported rather than raised: raising would
    # make a confirmed merge look like a failed one.
    def apply
      ensure_repository_label
      path = "repos/#{@github.repository}/issues/#{@github.number}/labels"
      @github.api(path, method: 'POST', fields: { labels: [NAME] }, expected: Array)
      'applied'
    rescue StandardError => e
      "failed: #{e.message}"
    end

    # A new repository label gets this color and description; an existing one keeps the maintainer's.
    def ensure_repository_label
      @github.api("repos/#{@github.repository}/labels/#{NAME}")
    rescue Error => e
      raise unless e.http_status == NOT_FOUND

      create
    end

    def create
      fields = { name: NAME, color: COLOR, description: DESCRIPTION }
      @github.api("repos/#{@github.repository}/labels", method: 'POST', fields:)
    rescue Error => e
      raise unless TOLERATED_CREATE_FAILURES.include?(e.http_status)
    end
  end
end
