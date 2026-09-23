# frozen_string_literal: true

module Shaka
  # Shared commit and reviewer attestation checks for both evidence paths.
  module LocalReviewEvidence
    SHA = /\A[0-9a-f]{40}\z/

    def self.valid?(text, head:, reviewer:, effort: nil)
      expected_effort = effort ? Regexp.escape(effort) : '\S+'
      prefix = "(?:\\A|\\n)REVIEWED #{Regexp.escape(head)} BY #{Regexp.escape(reviewer)} EFFORT "
      pattern = Regexp.new("#{prefix}#{expected_effort} FINDINGS \\d+\\s*\\z")
      text.match?(pattern)
    end
  end
end
