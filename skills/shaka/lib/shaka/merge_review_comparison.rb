# frozen_string_literal: true

module Shaka
  # Decides whether the commits after a reviewed revision changed only ordinary Markdown.
  module MergeReviewComparison
    # GitHub's compare API lists at most this many files, so a full page may hide code changes.
    COMPARE_FILE_LIMIT = 300
    # Markdown that instructs agents can change trust or merge policy, so it needs fresh review.
    INSTRUCTION_FILES = %w[agents.md claude.md gemini.md skill.md].freeze
    INSTRUCTION_DIRECTORIES = %w[.agents/ .claude/ .cursor/ .github/ skills/].freeze

    module_function

    def problem(comparison)
      return 'it is not an ancestor of the head' unless comparison.is_a?(Hash) && comparison['status'] == 'ahead'

      files = comparison['files']
      return 'the file list is missing' unless files.is_a?(Array) && files.all?(Hash)
      return 'the file list may be truncated' if files.length >= COMPARE_FILE_LIMIT

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
