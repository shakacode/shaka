# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Reports, for each check failing on a PR head, how the same-named check ended on the newest
  # commit of the PR's base branch. A shared name tells the agent which two logs to compare; it
  # does not show that the PR left the failure alone.
  class BaseChecks
    # Base buckets beyond `gh pr checks` ones: no check of that name, or rows that disagree.
    MISSING = 'missing'
    MIXED = 'mixed'

    # The newest commit on base_ref and its check rows grouped by name.
    def self.read(github, base_ref)
      raise Error, 'GitHub did not report the base branch.' unless base_ref.is_a?(String) && !base_ref.empty?

      sha = github.branch_tip(base_ref)
      [sha, github.rest_checks(sha).group_by { |row| row['name'] }]
    end

    # The base bucket for one check name: `fail`, `pass`, `pending`, and so on, or MISSING or MIXED.
    def self.bucket(rows)
      return MISSING if rows.nil? || rows.empty?

      buckets = rows.map { |row| row['bucket'] }.uniq
      buckets.one? ? buckets.first : MIXED
    end

    def initialize(github)
      @github = github
    end

    # head_checks are `gh pr checks` rows. required_names is nil when required checks are unknown.
    # Returns nothing to report when no head check fails, so a green PR costs no base reads.
    def call(base_ref, head_checks, required_names)
      failing = head_checks.select { |check| check['bucket'] == 'fail' }
      return {} if failing.empty?

      sha, on_base = self.class.read(@github, base_ref)
      failing = failing.map { |check| entry(check, on_base[check['name']], required_names) }
      { 'baseChecks' => { 'baseRefName' => base_ref, 'baseSha' => sha, 'failing' => failing } }
    end

    private

    def entry(check, rows, required_names)
      { 'name' => check['name'], 'required' => required_names&.include?(check['name']),
        'link' => check['link'], 'base' => self.class.bucket(rows), 'baseLink' => rows&.first&.fetch('link', nil) }
    end
  end
end
