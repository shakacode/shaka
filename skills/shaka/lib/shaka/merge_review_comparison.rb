# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Decides whether a review of an earlier commit still covers the head: either only ordinary
  # Markdown changed since, or updating from the base left the PR's own changes identical.
  class MergeReviewComparison
    # GitHub's compare API lists at most this many files, so a full page may hide code changes.
    COMPARE_FILE_LIMIT = 300
    # Markdown that instructs agents can change trust or merge policy, so it needs fresh review.
    INSTRUCTION_FILES = %w[agents.md claude.md gemini.md skill.md].freeze
    INSTRUCTION_DIRECTORIES = %w[.agents/ .claude/ .cursor/ .github/ skills/].freeze
    # Only the positions move when the base adds lines above a hunk.
    HUNK_POSITION = /^@@ -\d+(?:,\d+)? \+\d+(?:,\d+)? @@/

    def initialize(github, head:, base: nil)
      @github = github
      @head = head
      @base = base
    end

    # Returns what the match rests on, or nil after recording why the review does not apply.
    def match(reviewed, rejected)
      changed = markdown_only_changes(reviewed, rejected)
      return { 'basis' => 'markdown_only_since_review', 'changed_since_review' => changed } if changed

      { 'basis' => 'unchanged_since_review' } if @base && same_changes?(reviewed, rejected)
    end

    private

    def markdown_only_changes(reviewed, rejected)
      comparison = @github.compare(reviewed, @head)
      problem = markdown_problem(comparison)
      return comparison['files'].map { |file| file['filename'] } unless problem

      rejected << "#{reviewed}: #{problem}"
      nil
    rescue Error => e
      rejected << "#{reviewed}: comparison unavailable (#{e.message})"
      nil
    end

    def same_changes?(reviewed, rejected)
      before = changes(@github.compare(@base, reviewed))
      after = @head_changes ||= changes(@github.compare(@base, @head))
      problem = if before.nil? || after.nil? then 'its changes against the base cannot be compared'
                elsif before != after then 'the PR changes differ from what was reviewed'
                end
      rejected << "#{reviewed}: #{problem}" if problem
      problem.nil?
    rescue Error => e
      rejected << "#{reviewed}: base comparison unavailable (#{e.message})"
      false
    end

    # A file GitHub omits the patch for, other than a pure rename, cannot be proven unchanged.
    def changes(comparison)
      files = listed_files(comparison)
      return unless files&.all? { |file| file['patch'].is_a?(String) || file['changes'].to_i.zero? }

      files.map do |file|
        [file['filename'], file['previous_filename'], file['status'], file['patch'].to_s.gsub(HUNK_POSITION, '@@')]
      end.sort_by(&:to_s)
    end

    def listed_files(comparison)
      files = comparison.is_a?(Hash) ? comparison['files'] : nil
      files if files.is_a?(Array) && files.all?(Hash) && files.length < COMPARE_FILE_LIMIT
    end

    def markdown_problem(comparison)
      return 'it is not an ancestor of the head' unless comparison.is_a?(Hash) && comparison['status'] == 'ahead'

      files = listed_files(comparison)
      return 'the file list is missing or may be truncated' unless files

      code = non_markdown_paths(files)
      "changes since review need fresh review: #{code.first(3).join(', ')}" unless code.empty?
    end

    # A rename counts from both sides, so moving code into a .md name is still a code change.
    def non_markdown_paths(files)
      files.flat_map { |file| file.values_at('filename', 'previous_filename').compact }
           .reject { |path| prose?(path) }.uniq
    end

    def prose?(path)
      return false unless path.is_a?(String)

      name = path.downcase
      name.end_with?('.md') && !INSTRUCTION_FILES.include?(File.basename(name)) &&
        INSTRUCTION_DIRECTORIES.none? { |directory| name.start_with?(directory) || name.include?("/#{directory}") }
    end
  end
end
