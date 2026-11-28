# frozen_string_literal: true

module Shaka
  # The optional account of one companion run: whether it was manual, and what it led to in fixed labels a later
  # study can count. The agent reports it; Ruby checks shape.
  class CompanionOutcome
    FIELDS = %w[manual outcome caused_commits].freeze
    LABELS = { 'findings_applied' => 'Findings applied', 'findings_not_applied' => 'Findings not applied',
               'no_findings' => 'No findings' }.freeze
    SHA = /\A\h{40}\z/

    def initialize(entry)
      @entry = entry
    end

    def lines = [outcome_line].compact

    def manual?
      manual = @entry.fetch('manual', false)
      return manual if [true, false].include?(manual)

      raise Error, 'Publication companion_results manual must be true or false.'
    end

    private

    def outcome_line
      commits = caused_commits
      return unless @entry.key?('outcome')

      label = LABELS.fetch(@entry['outcome']) do
        raise Error, "Publication companion_results outcome must be one of #{LABELS.keys.join(', ')}."
      end
      "**Outcome:** #{[label, (code_list(commits) if commits.any?)].compact.join(' · ')}"
    end

    def caused_commits
      changed = @entry['outcome'] == 'findings_applied'
      return [] unless changed || @entry.key?('caused_commits')

      commits = @entry['caused_commits']
      return commits if changed && shas?(commits)

      raise Error, 'Publication companion_results caused_commits must list full SHAs for a findings_applied outcome ' \
                   'and be absent otherwise.'
    end

    def shas?(values) = values.is_a?(Array) && values.any? && values.all? { |sha| sha.is_a?(String) && SHA.match?(sha) }

    def code_list(values) = values.map { |value| "`#{value}`" }.join(', ')
  end
end
