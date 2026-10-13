# frozen_string_literal: true

module Shaka
  # Chooses the checks that gate a PR. GitHub's native required checks win; the trusted
  # seam's merge.required_checks applies only when GitHub enforces none, as on a private
  # repository whose plan offers no branch protection.
  class RequiredChecks
    def initialize(github, seam_names: nil)
      @github = github
      @seam_names = seam_names
    end

    def call
      native = @github.required_checks
      return github(native) unless native == []

      # An empty required-only report can omit checks already present on the head.
      configured = @github.configured_required_checks
      return github(check_rows(configured)) unless configured.empty?
      return github([]) unless @seam_names&.any?

      { 'source' => 'seam', 'checks' => check_rows(@seam_names) }
    end

    private

    def github(checks) = { 'source' => 'github', 'checks' => checks }

    def missing(name) = { 'name' => name, 'state' => 'MISSING', 'bucket' => 'missing' }

    # A declared check that never reported on the head must block, so a renamed or removed
    # job fails closed instead of silently dropping out of the gate.
    def check_rows(names)
      head = @github.checks
      names.flat_map do |name|
        rows = head.select { |row| row.is_a?(Hash) && row['name'] == name }
        rows.empty? ? [missing(name)] : rows
      end
    end
  end
end
