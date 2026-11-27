# frozen_string_literal: true

module Shaka
  # The optional account of one companion run: whether it was manual, and what it led to in fixed labels a later
  # study can count. The agent reports it; Ruby checks shape.
  class CompanionOutcome
    FIELDS = %w[manual outcome caused_commits cleared_paths].freeze
    LABELS = { 'changed_code' => 'Changed code', 'findings_not_applied' => 'Findings not applied',
               'no_findings' => 'No findings' }.freeze
    SHA = /\A\h{40}\z/
    # Repository-relative paths and globs only, so a cleared path can be compared with a PR's changed files.
    # Home directories and URI schemes are refused here; workstation roots anywhere in the value, by LOCAL_PATH.
    UNSAFE_PATH = %r{\A[/~]|\A[a-zA-Z][\w+.-]*:|(?:\A|/)\.\.(?:/|\z)|[`\\<>[:cntrl:]]}

    def initialize(entry)
      @entry = entry
    end

    def lines = [outcome_line, cleared_line].compact

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
      changed = @entry['outcome'] == 'changed_code'
      return [] unless changed || @entry.key?('caused_commits')

      commits = @entry['caused_commits']
      return commits if changed && shas?(commits)

      raise Error, 'Publication companion_results caused_commits must list full SHAs for a changed_code outcome ' \
                   'and be absent otherwise.'
    end

    def shas?(values) = values.is_a?(Array) && values.any? && values.all? { |sha| sha.is_a?(String) && SHA.match?(sha) }

    def cleared_line
      paths = @entry.fetch('cleared_paths', [])
      unless paths.is_a?(Array) && paths.all? { |path| repository_path?(path) }
        raise Error, 'Publication companion_results cleared_paths must list repository-relative paths.'
      end

      "**Cleared paths:** #{code_list(paths)}" if paths.any?
    end

    def repository_path?(path)
      # Markdown trims a code span's edge spaces, so a padded value could render as an absolute path.
      path.is_a?(String) && !path.empty? && path == path.strip && !UNSAFE_PATH.match?(path) &&
        !CompanionResults::LOCAL_PATH.match?(path.tr('*?', 'x')) # a glob's `**/bin/` is not a workstation root
    end

    def code_list(values) = values.map { |value| "`#{value}`" }.join(', ')
  end
end
