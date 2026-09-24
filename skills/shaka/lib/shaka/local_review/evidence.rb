# frozen_string_literal: true

module Shaka
  # Shared commit and reviewer attestation checks for both evidence paths.
  module LocalReviewEvidence
    SHA = /\A[0-9a-f]{40}\z/

    def self.valid?(text, head:, reviewer:, effort: nil)
      return false unless text.valid_encoding?

      expected_effort = effort ? Regexp.escape(effort) : '\S+'
      # Fold reviewer case only. review-prompt keeps the given spelling; review check compares
      # the lowercased identity, and an exact match rejects a copied line.
      identity = Regexp.escape(reviewer).gsub(/[A-Za-z]/) { |char| "[#{char.upcase}#{char.downcase}]" }
      prefix = "(?:\\A|\\n)REVIEWED #{Regexp.escape(head)} BY #{identity} EFFORT "
      pattern = Regexp.new("#{prefix}#{expected_effort} FINDINGS \\d+\\s*\\z")
      text.match?(pattern)
    end
  end
end
