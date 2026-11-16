# frozen_string_literal: true

module Shaka
  # The test classes a validation run reports as failing, such as ["EvaluationDriverReviewTest"], so a
  # timings report can rank the tests that fail most often and separate flaky tests from real failures.
  # The command is candidate code, the names are published, and a body is editable, so every reader
  # passes them through `sanitize` again.
  module FailedTests
    NAME = /\A[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*\z/
    MAX_LENGTH = 64
    # Kept small because each failing run carries its names in the pull request body.
    MAX_NAMES = 3

    module_function

    # The distinct class-shaped names, sorted, at most MAX_NAMES of them; anything else is skipped.
    def sanitize(names)
      return [] unless names.is_a?(Array)

      names.select { |name| shaped?(name) }.uniq.sort.first(MAX_NAMES)
    end

    def shaped?(name) = name.is_a?(String) && name.length <= MAX_LENGTH && NAME.match?(name)
  end
end
