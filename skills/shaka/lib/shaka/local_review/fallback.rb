# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/text'

module Shaka
  # The review comment's notice for a reviewer fallback. Recording renders it too, so a ledger
  # refuses a fallback when it is recorded rather than when it is published.
  module LocalReviewFallback
    OUTCOMES = %w[different_provider same_provider same_model].freeze
    SETUP_GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#add-a-second-reviewer'
    # A setup failure's reason can name a file on the reviewer's machine; a public PR must not show it.
    # A path can contain spaces, so everything from its first character on is dropped.
    LOCAL_PATH = %r{(?<![\w./-])(?:~|/).*}m

    module_function

    def notice(fallback)
      return [] if fallback.nil?
      raise Error, 'Local review fallback must be an object.' unless fallback.is_a?(Hash)

      outcome = fallback['outcome']
      raise Error, "Local review fallback outcome must be one of #{OUTCOMES.join(', ')}." unless
        OUTCOMES.include?(outcome)
      return [] if outcome == 'different_provider'

      [(['**Reviewer fallback:** no reviewer from a different provider ran, so this review ' \
         "used `#{outcome}`. [Add a second reviewer](#{SETUP_GUIDE}) to avoid this."] + attempts(fallback)).join("\n")]
    end

    # Selection can fall back without trying anything, as when no other provider is configured.
    def attempts(fallback)
      tried = PublicationText.list(fallback['attempts'], 'fallback attempts')
      return [] if tried.empty?

      ['', 'Tried:', ''] + tried.map { |attempt| attempt_line(attempt) }
    end

    def attempt_line(attempt)
      raise Error, 'Each fallback attempt must be an object.' unless attempt.is_a?(Hash)

      reviewer = PublicationText.single_line(attempt['reviewer'], 'fallback reviewer')
      stage = PublicationText.single_line(attempt['failure_stage'], 'fallback failure_stage')
      reason = PublicationText.single_line(attempt['reason'], 'fallback reason').sub(LOCAL_PATH, '[path]')
      "- `#{reviewer}`: `#{stage}`: #{reason}"
    end
    private_class_method :attempts, :attempt_line
  end
end
