# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Chooses the checks that gate a PR: GitHub's native required checks plus any the trusted
  # seam's merge.required_checks adds. The source is `github`, `seam` when GitHub enforces
  # none, or `github+seam`; any seam source means GitHub will not stop a merge on those checks.
  class RequiredChecks
    def initialize(github, seam_names: nil)
      @github = github
      @seam_names = seam_names
    end

    def call
      native = @github.required_checks
      return github(native) unless native.is_a?(Array)

      # The required-only report omits configured checks that never reported, and an empty
      # one can omit checks already present on the head.
      checks = native + check_rows(@github.configured_required_checks - names(native))
      added = Array(@seam_names) - names(checks)
      return github(checks) if added.empty?

      { 'source' => checks.empty? ? 'seam' : 'github+seam', 'checks' => checks + check_rows(added) }
    end

    def self.verify_passing!(checks)
      raise Error, 'No observable required checks; native readiness is unknown' unless checks.is_a?(Array)

      checks.each do |check|
        next if passing?(check)

        raise Error, "Required check is not passing or is malformed: #{check.inspect}"
      end
    end

    def self.passing?(check)
      return false unless check.is_a?(Hash) && check['name'].is_a?(String) && !check['name'].strip.empty?

      case check['state']
      when 'SUCCESS' then check['bucket'] == 'pass'
      when 'NEUTRAL', 'SKIPPED' then check['bucket'] == 'skipping'
      else false
      end
    end

    private

    def github(checks) = { 'source' => 'github', 'checks' => checks }

    def names(rows) = rows.map { |row| row['name'] if row.is_a?(Hash) }

    def missing(name) = { 'name' => name, 'state' => 'MISSING', 'bucket' => 'missing' }

    # A declared check that never reported on the head must block, so a renamed or removed
    # job fails closed instead of silently dropping out of the gate.
    def check_rows(names)
      return [] if names.empty?

      head = (@head ||= @github.checks)
      names.flat_map do |name|
        rows = head.select { |row| row.is_a?(Hash) && row['name'] == name }
        rows.empty? ? [missing(name)] : rows
      end
    end
  end
end
