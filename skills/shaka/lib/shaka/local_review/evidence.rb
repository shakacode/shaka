# frozen_string_literal: true

module Shaka
  # Shared commit and reviewer attestation checks for both evidence paths.
  module LocalReviewEvidence
    SHA = /\A[0-9a-f]{40}\z/
    # The effort and finding count an attestation closes with.
    CLOSING = /EFFORT (\S+) FINDINGS (\d+)\s*\z/

    # A main review comment's header down to its Outcome line. Anchored at the start so no report,
    # and no continuation comment of earlier reports, can write or restate that line.
    OUTCOME = Regexp.new('\A(?:<!-- shaka:reply:[^\n]* -->\n)?# Local Adversarial Review\n\n' \
                         '<!-- shaka:local-reviewers [^\n]* -->\n\n' \
                         '\*\*Reviewed revision:\*\* [^\n]*\n\n\*\*Outcome:\*\* ([^\n]*)$').freeze

    # How many findings a published review says need attention, or nil when body is not a main review comment.
    def self.pending_count(body)
      # GitHub's web editor stores CRLF, and the attestation that goes with this line tolerates it.
      outcome = body.gsub("\r\n", "\n")[OUTCOME, 1]
      outcome && outcome[/\A(\d+) findings? needs? attention/, 1].to_i
    end

    def self.valid?(text, head:, reviewer:, effort: nil)
      return false unless text.valid_encoding?

      expected_effort = effort ? Regexp.escape(effort) : '\S+'
      # Fold reviewer case only. review-prompt keeps the given spelling; an exact match would
      # reject a copied line. The inline group leaves Regexp.escape sequences intact.
      identity = "(?i:#{Regexp.escape(reviewer)})"
      prefix = "(?:\\A|\\n)REVIEWED #{Regexp.escape(head)} BY #{identity} EFFORT "
      pattern = Regexp.new("#{prefix}#{expected_effort} FINDINGS \\d+\\s*\\z")
      text.match?(pattern)
    end
  end
end
